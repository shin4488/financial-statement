# バックエンド実装詳細 — 取得層（Ingestion）

> 各クラスの入出力に実データ（武田・三菱UFJ）を通した例は [07_data_flow_example.md](07_data_flow_example.md) にある。
> 実装時は必ず併読すること（Extractor出力ハッシュの具体形、フォールバックのヒット例、
> 「キーがない=開示なし」の実例が載っている）。

## 0. 事前準備

### Gemfile

```ruby
gem "nokogiri"   # XBRLパース用。REXML（現行）は巨大TextBlockでentity expansionエラーになるため置き換える
gem "rubyzip"    # 既存Gemfileに入っているはず（zip展開）。なければ追加
```

`bundle install` 後、既存コードの `REXML` 依存（`AppFile::XmlParser`）はこの再設計では使わない
（旧コードの削除タイミングは [06](06_rollout.md)）。

### ジョブ登録（sidekiq-cron）

`config/sidekiq-cron.yml` のエントリを新ジョブに差し替える:

```yaml
daily_ingestion_job:
  # 毎日2:00（現行と同じ時刻。EDINETの書類一覧は前日分が対象なので深夜でよい）
  cron: "0 0 2 * * *"
  class: DailyIngestionJob
  queue: default
```

### 環境変数

新規追加はなし。`EDINET_API_KEY` を既存どおり `config/application.yml`（figaro・gitignore済み）で
供給する。テストでは実APIを呼ばない（webmockで遮断・実XBRLはfixture）。

## ディレクトリ構成

```
app/
  lib/
    financial_statements/item_codes.rb     # 科目コードレジストリ（02参照）
    edinet/client.rb                       # EDINET APIクライアント
    xbrl/document.rb                       # XBRL fact検索プリミティブ
  services/
    ingestion/
      format_registry.rb                   # 形式の一覧と形式→Extractor/Builderの対応
      format_detector.rb                   # 形式判定
      dei_extractor.rb                     # DEI・企業情報の抽出
      report_ingester.rb                   # オーケストレーション + 永続化
      daily_ingestion_service.rb           # 日次実行のエントリポイント
      extractors/
        base.rb
        jgaap_general.rb
        jgaap_bank.rb
        ifrs_classified.rb
        ifrs_liquidity.rb
  jobs/
    daily_ingestion_job.rb                 # sidekiq-cron から起動
```

## Edinet::Client

外部I/Oをここに集約する。APIキーは環境変数。レート制限（403対策）のため同期・逐次実行が前提。

```ruby
# app/lib/edinet/client.rb
module Edinet
  class Client
    BASE = "https://disclosure.edinet-fsa.go.jp/api/v2".freeze
    # EDINETの書類種別コード。120=有価証券報告書、130=訂正有価証券報告書。
    # 訂正も取り込む理由: 数値誤りの訂正が本表に及ぶことがあり、上書き取込（冪等upsert）で
    # 最新の正しい値に置き換えるため
    ANNUAL_REPORT = "120".freeze
    AMENDED_ANNUAL_REPORT = "130".freeze

    DocumentMeta = Struct.new(:doc_id, :sec_code, :filer_name, :doc_type_code, keyword_init: true)

    # その日に提出された上場企業の有報・訂正有報の一覧
    def list_annual_reports(date:)
      uri = URI("#{BASE}/documents.json")
      # type=2: 提出書類一覧とメタデータを返すモード（type=1はメタデータのみ）
      uri.query = URI.encode_www_form(date: date, type: 2, "Subscription-Key" => api_key)
      results = JSON.parse(Net::HTTP.get(uri))["results"] || []
      results.filter_map do |r|
        # secCodeなし = 非上場（投資信託・組合等の提出物）。本アプリの対象外
        next if r["secCode"].nil?
        next unless [ANNUAL_REPORT, AMENDED_ANNUAL_REPORT].include?(r["docTypeCode"])
        DocumentMeta.new(doc_id: r["docID"], sec_code: r["secCode"],
                         filer_name: r["filerName"], doc_type_code: r["docTypeCode"])
      end
    end

    # zipをダウンロードし、PublicDoc配下のXBRLインスタンスを展開してパスを返す（なければnil）
    # work_dir はバッチが用意した一時ディレクトリ。呼び出し側が後始末する
    def download_xbrl(doc_id:, work_dir:)
      zip_path = File.join(work_dir, "#{doc_id}.zip")
      # 書類取得APIの type=1 は「提出本文書及び監査報告書」のzip
      uri = URI("#{BASE}/documents/#{doc_id}")
      uri.query = URI.encode_www_form(type: 1, "Subscription-Key" => api_key)
      uri.open { |src| File.binwrite(zip_path, src.read) }  # zipはバイナリなのでbinwrite

      xbrl_path = nil
      Zip::File.open(zip_path) do |zip|
        # PublicDoc = 提出本文（財務諸表を含む）。AuditDoc（監査報告書）側のXBRLは対象外。
        # 本文XBRLインスタンスは1書類に1つ。無い書類（一部の訂正有報など）はnilを返し
        # 呼び出し側が「財務データなし」としてスキップする
        entry = zip.glob("*/PublicDoc/*.xbrl").first
        next if entry.nil?
        xbrl_path = File.join(work_dir, "#{doc_id}.xbrl")
        zip.extract(entry, xbrl_path) { true }  # ブロックtrue = 既存ファイルは上書き（リトライ時）
      end
      xbrl_path
    ensure
      # zipは展開後すぐ消す: 全上場企業分を貯めるとディスクを圧迫する（1書類数MB×日次数十件）
      FileUtils.rm_f(zip_path)
    end

    private
      def api_key = ENV.fetch("EDINET_API_KEY")
  end
end
```

## Xbrl::Document

fact検索のプリミティブ。**ここより上の層はXMLを知らない**。

設計判断2点:
- REXML（現行実装）ではなく**Nokogiri**を使う。REXMLは有報の巨大TextBlock（HTML断片）で
  entity expansionエラーを起こすことを実測で確認済みのため
- `remove_namespaces!` は**使わない**。企業拡張タクソノミ要素（例: NTTの
  `jpcrp030000-asr_E04430-000:OperatingRevenuesIFRS`）と標準要素が同名で衝突し得るため、
  「namespace URIがどの標準タクソノミか」で引く

```ruby
# app/lib/xbrl/document.rb
module Xbrl
  class Document
    NS = {
      "jpdei_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpdei/},
      "jppfs_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jppfs/},
      "jpigp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpigp/},
      "jpcrp_cor" => %r{disclosure\.edinet-fsa\.go\.jp/taxonomy/jpcrp/},
    }.freeze
    # タクソノミはバージョン年度がURIに含まれる（例 .../jppfs/2025-11-01/jppfs_cor）ため正規表現で吸収

    def self.load(path)
      new(Nokogiri::XML(File.open(path)) { |cfg| cfg.huge })
    end

    def initialize(doc)
      @doc = doc
      # {["jppfs_cor", "NetSales", "CurrentYearDuration"] => "12345", ...} を1passで構築。
      # 科目ごとにXPath検索する方式（現行アプリ）だと科目数×全要素走査になるため、
      # 先に全factをハッシュ化して以降の検索をO(1)にする
      @facts = {}
      doc.root.element_children.each do |el|
        ctx = el.attribute("contextRef")&.value
        next if ctx.nil?  # contextRefなし = fact以外の要素（unit定義など）
        # 名前空間URIからプレフィクスを正引き。企業拡張タクソノミ（jpcrp030000-asr_EXXXXX-000等）は
        # NSにマッチせずここで弾かれる = 標準タグのみを対象とする（意図的。拡張タグは企業ごとに
        # 意味の保証がないため、必要になったら NS に追加する形で明示的にオプトインする）
        prefix = NS.find { |_, pattern| el.namespace&.href&.match?(pattern) }&.first
        next if prefix.nil?
        # ||= : 同じ要素×同じコンテキストのfactは本表と注記で重複出現することがある（実測あり）。
        # 値は同一のはずだが、万一異なっても文書の先頭側（本表側）を採用する
        @facts[[prefix, el.name, ctx]] ||= el.text&.strip
      end
    end

    # "jppfs_cor:NetSales" 形式のqnameとコンテキストで整数値を引く。なければnil
    def money(qname, context)
      prefix, name = qname.split(":")
      raw = @facts[[prefix, name, context]]
      return nil if raw.nil? || raw.empty?
      # exception: false → 数値でない値（空タグ・テキスト）はnil扱い。
      # to_iを使わない理由: to_iは"abc"を0にしてしまい「開示なし」と「ゼロ」の区別が壊れる
      Integer(raw, exception: false)
    end

    # フォールバックリスト: 最初に値が取れたものを返す（リストの並び順=優先度）
    def money_first(qnames, context)
      qnames.lazy.filter_map { |q| money(q, context) }.first
    end

    def text(qname, context)
      prefix, name = qname.split(":")
      @facts[[prefix, name, context]]
    end
  end
end
```

全factを1回のスキャンでハッシュ化するため、科目数×XPath検索だった現行実装より大幅に速い。

## Ingestion::DeiExtractor

```ruby
# app/services/ingestion/dei_extractor.rb
module Ingestion
  class DeiExtractor
    FILING = "FilingDateInstant".freeze

    Result = Struct.new(
      :edinet_code, :stock_code, :name_ja, :name_en,
      :accounting_standard, :has_consolidated,
      :fiscal_year_start_date, :fiscal_year_end_date, :filing_date,
      :consolidated_industry_code, :non_consolidated_industry_code,
      keyword_init: true
    )

    STANDARD_MAP = { "Japan GAAP" => "japan_gaap", "US GAAP" => "us_gaap", "IFRS" => "ifrs" }.freeze

    def extract(xbrl)
      Result.new(
        edinet_code: xbrl.text("jpdei_cor:EDINETCodeDEI", FILING),
        stock_code: xbrl.text("jpdei_cor:SecurityCodeDEI", FILING),  # 5桁（例: "45020"）のまま保存。4桁化は表示層の責務
        # 企業名は表紙（CoverPage）を優先し、表紙タグがない書類はDEIの提出者名にフォールバック（現行アプリの知見を踏襲）
        name_ja: normalize_width(xbrl.text("jpcrp_cor:CompanyNameCoverPage", FILING) ||
                                 xbrl.text("jpdei_cor:FilerNameInJapaneseDEI", FILING)),
        name_en: normalize_width(xbrl.text("jpcrp_cor:CompanyNameInEnglishCoverPage", FILING) ||
                                 xbrl.text("jpdei_cor:FilerNameInEnglishDEI", FILING)),
        accounting_standard: STANDARD_MAP.fetch(xbrl.text("jpdei_cor:AccountingStandardsDEI", FILING), nil),
        has_consolidated: xbrl.text("jpdei_cor:WhetherConsolidatedFinancialStatementsArePreparedDEI", FILING) == "true",
        fiscal_year_start_date: xbrl.text("jpdei_cor:CurrentFiscalYearStartDateDEI", FILING),
        fiscal_year_end_date: xbrl.text("jpdei_cor:CurrentFiscalYearEndDateDEI", FILING),
        filing_date: xbrl.text("jpcrp_cor:FilingDateCoverPage", FILING),
        consolidated_industry_code:
          xbrl.text("jpdei_cor:IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI", FILING),
        non_consolidated_industry_code:
          xbrl.text("jpdei_cor:IndustryCodeWhenFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI", FILING),
      )
    end

    private
      # 全角英数字・スペース・アンパサンドを半角へ正規化する（現行アプリ踏襲）。
      # 意図: EDINET上の企業名は「ＮＴＴ株式会社」のように全角英数で登録されており、
      # そのままだと証券コード検索やUI表示・照合で半角と混在して扱いにくいため
      def normalize_width(text)
        text&.tr("０-９ａ-ｚＡ-Ｚ　＆", "0-9a-zA-Z &")
      end
  end
end
```

## Ingestion::FormatRegistry / FormatDetector

```ruby
# app/services/ingestion/format_registry.rb
module Ingestion
  module FormatRegistry
    JGAAP_GENERAL   = "jgaap_general"
    JGAAP_BANK      = "jgaap_bank"
    IFRS_CLASSIFIED = "ifrs_classified"
    IFRS_LIQUIDITY  = "ifrs_liquidity"
    UNSUPPORTED     = "unsupported"
    ALL = [JGAAP_GENERAL, JGAAP_BANK, IFRS_CLASSIFIED, IFRS_LIQUIDITY, UNSUPPORTED].freeze

    EXTRACTORS = {
      JGAAP_GENERAL   => Extractors::JgaapGeneral,
      JGAAP_BANK      => Extractors::JgaapBank,
      IFRS_CLASSIFIED => Extractors::IfrsClassified,
      IFRS_LIQUIDITY  => Extractors::IfrsLiquidity,
    }.freeze

    def self.extractor_for(format) = EXTRACTORS[format]  # unsupportedはnil
  end
end
```

```ruby
# app/services/ingestion/format_detector.rb
# （FormatRegistryとは別ファイル: Zeitwerkはクラス名とファイル名の一致を要求する）
module Ingestion
  class FormatDetector
    # 日本基準の業種DEIコード → 形式。未知の業種はunsupported（安全側）
    # 実測済み: cte=一般（電気通信含む汎用）, bnk=銀行。空値も一般扱い
    JGAAP_INDUSTRY_FORMATS = {
      nil => FormatRegistry::JGAAP_GENERAL,
      "" => FormatRegistry::JGAAP_GENERAL,
      "cte" => FormatRegistry::JGAAP_GENERAL,
      "bnk" => FormatRegistry::JGAAP_BANK,
      # 保険・証券等は実測の上でここに追加していく（例: "ins" => JGAAP_INSURANCE）
    }.freeze

    # consolidation は Extractors::Base::CONSOLIDATED / NON_CONSOLIDATED
    def detect(xbrl, accounting_standard:, industry_code:, consolidation:)
      case accounting_standard
      when "japan_gaap"
        # downcase する理由: 業種DEIコードは大文字小文字が揺れる
        # （実測: 三菱UFJ="bnk"小文字、東京海上="INS"大文字、一般="cte"/"CTE"両方あり）
        JGAAP_INDUSTRY_FORMATS.fetch(industry_code&.downcase, FormatRegistry::UNSUPPORTED)
      when "ifrs"
        # IFRSのBS 2様式（流動/非流動 511000・流動性配列 512000）はDEIでは区別できないため
        # 「流動資産合計タグの実在」で判定する（01参照。楽天は本タグが0件だった）。
        # moneyがnil = タグ自体がない or 数値でない、のどちらでも流動性配列側に倒れるが、
        # その場合BsIfrsLiquidityは合計科目だけで描けるため安全側の誤判定になる
        if xbrl.money("jpigp_cor:CurrentAssetsIFRS", "CurrentYearInstant#{consolidation}")
          FormatRegistry::IFRS_CLASSIFIED
        else
          FormatRegistry::IFRS_LIQUIDITY
        end
      else
        FormatRegistry::UNSUPPORTED  # us_gaap: 本表の詳細タグがEDINETタクソノミに存在しない
      end
    end
  end
end
```

## Extractor（形式別マッピング）

### 基底クラス

```ruby
# app/services/ingestion/extractors/base.rb
module Ingestion
  module Extractors
    class Base
      # XBRLコンテキストIDのサフィックス。連結はサフィックスなし、単体は_NonConsolidatedMember
      # （例: CurrentYearInstant / CurrentYearInstant_NonConsolidatedMember。全形式共通の規則・01参照）
      CONSOLIDATED = "".freeze
      NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

      def initialize(xbrl, consolidation)
        @xbrl = xbrl
        @c = consolidation  # コンテキストサフィックス
      end

      # {item_code => amount} を返す。取れなかった科目はキーごと入れない
      # （「開示なし」をnilや0でなくキーの不存在で表す。02のDB設計と対になる規約）
      def extract
        result = {}
        # マッピングを2表に分ける理由: XBRLは科目の期間タイプごとにコンテキストIDが違う。
        # BS残高系=Instant（時点） / PL・CF増減系=Duration（期間）
        self.class::INSTANT_MAPPING.each do |code, qnames|
          # Array(): マッピングの値は「単一タグの文字列」か「フォールバック順の配列」の両記法を許す
          v = @xbrl.money_first(Array(qnames), "CurrentYearInstant#{@c}")
          result[code] = v unless v.nil?
        end
        self.class::DURATION_MAPPING.each do |code, qnames|
          v = @xbrl.money_first(Array(qnames), "CurrentYearDuration#{@c}")
          result[code] = v unless v.nil?
        end
        extract_extras(result)
        result
      end

      private
        # 単純な「1コード→タグのフォールバックリスト」で表せない科目のためのフック。
        # 具体例: 期首残高（Prior1YearInstantという別コンテキストを参照）、
        #         のれん+無形の合算（2タグの加算）。各形式クラスが必要な分だけ実装する
        def extract_extras(result); end

        def put(result, code, value)
          result[code] = value unless value.nil?
        end
    end
  end
end
```

### JgaapGeneral（現行アプリのマッピングを移植 + 期首/期末現金を追加）

```ruby
# app/services/ingestion/extractors/jgaap_general.rb
class Ingestion::Extractors::JgaapGeneral < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.current_assets"               => "jppfs_cor:CurrentAssets",
    "bs.tangible_fixed_assets"        => "jppfs_cor:PropertyPlantAndEquipment",
    "bs.intangible_fixed_assets"      => "jppfs_cor:IntangibleAssets",
    "bs.investments_and_other_assets" => "jppfs_cor:InvestmentsAndOtherAssets",
    "bs.non_current_assets"           => "jppfs_cor:NoncurrentAssets",
    "bs.assets"                       => "jppfs_cor:Assets",
    "bs.current_liabilities"          => "jppfs_cor:CurrentLiabilities",
    "bs.non_current_liabilities"      => "jppfs_cor:NoncurrentLiabilities",
    "bs.liabilities"                  => "jppfs_cor:Liabilities",
    "bs.equity"                       => "jppfs_cor:NetAssets",
    # 同じタグを2つの科目コードに保存する: 現金同等物はBSの科目としてもCFの期末残高としても
    # 消費される（消費先が違う）。縦持ちでは行が1つ増えるだけなので冗長保存を許容し、
    # Builder側が「どのコードを見ればよいか」で迷わないようにする
    "bs.cash_and_equivalents"         => "jppfs_cor:CashAndCashEquivalents",
    "cf.cash_end"                     => "jppfs_cor:CashAndCashEquivalents",
  }.freeze

  DURATION_MAPPING = {
    # 売上高（業種ゆれフォールバックは現行実装から踏襲。順序が優先度）
    "pl.revenue" => %w[
      jppfs_cor:NetSales
      jppfs_cor:ContractsCompletedRevOA
      jppfs_cor:NetSalesOfCompletedConstructionContractsCNS
    ],
    "pl.cost_of_sales" => %w[
      jppfs_cor:CostOfSales
      jppfs_cor:CostOfMerchandiseAndFinishedGoodsSoldCOS
      jppfs_cor:CostOfFinishedGoodsSold
      jppfs_cor:CostOfGoodsSold
      jppfs_cor:CostOfCompletedWorkCOSExpOA
      jppfs_cor:CostOfSalesOfCompletedConstructionContractsCNS
    ],
    "pl.gross_profit"           => "jppfs_cor:GrossProfit",
    "pl.sga"                    => "jppfs_cor:SellingGeneralAndAdministrativeExpenses",
    "pl.operating_profit"       => "jppfs_cor:OperatingIncome",
    "pl.non_operating_income"   => "jppfs_cor:NonOperatingIncome",
    "pl.non_operating_expenses" => "jppfs_cor:NonOperatingExpenses",
    "pl.ordinary_profit"        => "jppfs_cor:OrdinaryIncome",
    "pl.extraordinary_income"   => "jppfs_cor:ExtraordinaryIncome",
    "pl.extraordinary_loss"     => "jppfs_cor:ExtraordinaryLoss",
    "pl.profit_before_tax"      => "jppfs_cor:IncomeBeforeIncomeTaxes",
    "pl.income_tax"             => "jppfs_cor:IncomeTaxes",
    "pl.profit"                 => "jppfs_cor:ProfitLoss",
    "pl.profit_attributable_to_owners" => "jppfs_cor:ProfitLossAttributableToOwnersOfParent",
    "cf.operating" => "jppfs_cor:NetCashProvidedByUsedInOperatingActivities",
    "cf.investing" => "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities",  # JGAAPはInvestment（IFRSはInvesting。取り違え注意）
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities",
  }.freeze

  private
    def extract_extras(result)
      # CF期首残高だけは「前期末時点」= Prior1YearInstant コンテキストを見る必要があるため
      # マッピング表（CurrentYear固定）に載せられずここで実装（全Extractor共通のパターン）
      put(result, "cf.cash_begin",
          @xbrl.money("jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant#{@c}"))
    end
end
```

### JgaapBank（三菱UFJ FGで実測済みのタグ）

```ruby
# app/services/ingestion/extractors/jgaap_bank.rb
class Ingestion::Extractors::JgaapBank < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    # 銀行は流動/固定区分がないため合計3科目 + 業種固有の内訳のみ。
    # 合計科目のタグは一般事業会社と同じ汎用タグであることを実測で確認済み（01参照）
    "bs.assets"               => "jppfs_cor:Assets",
    "bs.liabilities"          => "jppfs_cor:Liabilities",
    "bs.equity"               => "jppfs_cor:NetAssets",
    "bs.loans"                => "jppfs_cor:LoansAndBillsDiscountedAssetsBNK",
    "bs.securities"           => "jppfs_cor:SecuritiesAssetsBNK",
    # BSの「現金預け金」とCFの「現金及び現金同等物」は銀行では別概念のため別タグ
    # （日銀預け金等の扱いが異なる。値が一致する銀行もあるが混同しないこと）
    "bs.cash_and_equivalents" => "jppfs_cor:CashAndDueFromBanksAssetsBNK",
    "bs.deposits"             => "jppfs_cor:DepositsLiabilitiesBNK",
    "cf.cash_end"             => "jppfs_cor:CashAndCashEquivalents",
  }.freeze

  DURATION_MAPPING = {
    # 銀行にpl.revenue（売上高）は存在しない。トップラインは経常収益。
    # OrdinaryIncome「BNK」= 経常収益、サフィックスなしOrdinaryIncome = 経常利益、と
    # 同系の名前で意味が全く違う。取り違えると桁が大きく狂う（14.6兆 vs 3.4兆）ので注意
    "pl.ordinary_revenue"   => "jppfs_cor:OrdinaryIncomeBNK",   # 経常収益
    "pl.ordinary_expenses"  => "jppfs_cor:OrdinaryExpensesBNK", # 経常費用
    "pl.ordinary_profit"    => "jppfs_cor:OrdinaryIncome",      # 経常利益（BNKなし・一般形式と同じ汎用タグ）
    "pl.extraordinary_income" => "jppfs_cor:ExtraordinaryIncome",
    "pl.extraordinary_loss"   => "jppfs_cor:ExtraordinaryLoss",
    "pl.profit_before_tax"  => "jppfs_cor:IncomeBeforeIncomeTaxes",
    "pl.income_tax"         => "jppfs_cor:IncomeTaxes",
    "pl.profit"             => "jppfs_cor:ProfitLoss",
    "pl.profit_attributable_to_owners" => "jppfs_cor:ProfitLossAttributableToOwnersOfParent",
    "cf.operating" => "jppfs_cor:NetCashProvidedByUsedInOperatingActivities",
    "cf.investing" => "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities",
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities",
  }.freeze

  private
    def extract_extras(result)
      put(result, "cf.cash_begin",
          @xbrl.money("jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant#{@c}"))
    end
end
```

### IfrsClassified（武田・三菱商事・NTTで実測済み）

```ruby
# app/services/ingestion/extractors/ifrs_classified.rb
class Ingestion::Extractors::IfrsClassified < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.current_assets"          => "jpigp_cor:CurrentAssetsIFRS",
    "bs.non_current_assets"      => "jpigp_cor:NonCurrentAssetsIFRS",
    "bs.assets"                  => "jpigp_cor:AssetsIFRS",
    "bs.current_liabilities"     => %w[jpigp_cor:TotalCurrentLiabilitiesIFRS jpigp_cor:CurrentLiabilitiesIFRS],
    # NonCurrentLabilities はタクソノミ公式のタイポ（実測済み）。正しい綴りもフォールバックに
    "bs.non_current_liabilities" => %w[jpigp_cor:NonCurrentLabilitiesIFRS jpigp_cor:NonCurrentLiabilitiesIFRS],
    "bs.liabilities"             => "jpigp_cor:LiabilitiesIFRS",
    "bs.equity"                  => "jpigp_cor:EquityIFRS",
    "bs.equity_attributable_to_owners" => "jpigp_cor:EquityAttributableToOwnersOfParentIFRS",
    "bs.non_controlling_interests"     => "jpigp_cor:NonControllingInterestsIFRS",
    "bs.property_plant_and_equipment"  => "jpigp_cor:PropertyPlantAndEquipmentIFRS",
    "bs.cash_and_equivalents"    => "jpigp_cor:CashAndCashEquivalentsIFRS",
    "cf.cash_end"                => "jpigp_cor:CashAndCashEquivalentsIFRS",
  }.freeze

  DURATION_MAPPING = {
    # 収益: 標準3系列 → 最後に経営指標サマリ（NTTのように本表の収益が企業拡張タグの場合の受け皿。
    # サマリの値は本表と一致することを4社で実測済み・01参照）。
    # サマリを最後に置く理由: 本表タグの方が一次情報であり、サマリは表示単位変更などの
    # リスクが理論上あるため、あくまでフォールバック
    "pl.revenue" => %w[
      jpigp_cor:RevenueIFRS
      jpigp_cor:Revenue2IFRS
      jpigp_cor:NetSalesIFRS
      jpcrp_cor:RevenueIFRSSummaryOfBusinessResults
    ],
    "pl.cost_of_sales"      => "jpigp_cor:CostOfSalesIFRS",
    "pl.gross_profit"       => "jpigp_cor:GrossProfitIFRS",
    "pl.sga"                => "jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS",
    "pl.operating_expenses" => "jpigp_cor:OperatingExpensesIFRS",
    "pl.operating_profit"   => "jpigp_cor:OperatingProfitLossIFRS",
    "pl.profit_before_tax"  => "jpigp_cor:ProfitLossBeforeTaxIFRS",
    "pl.income_tax"         => "jpigp_cor:IncomeTaxExpenseIFRS",
    "pl.profit"             => "jpigp_cor:ProfitLossIFRS",
    "pl.profit_attributable_to_owners" => "jpigp_cor:ProfitLossAttributableToOwnersOfParentIFRS",
    "cf.operating" => "jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS",
    "cf.investing" => "jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS",  # IFRSはInvesting
    "cf.financing" => "jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS",
  }.freeze

  private
    def extract_extras(result)
      put(result, "cf.cash_begin",
          @xbrl.money("jpigp_cor:CashAndCashEquivalentsIFRS", "Prior1YearInstant#{@c}"))
      # のれん・無形: 合算タグ（三菱商事型） or 別掲2タグの合算（武田型）
      combined = @xbrl.money("jpigp_cor:GoodwillAndIntangibleAssetsIFRS", "CurrentYearInstant#{@c}")
      if combined.nil?
        goodwill   = @xbrl.money("jpigp_cor:GoodwillIFRS", "CurrentYearInstant#{@c}")
        intangible = @xbrl.money("jpigp_cor:IntangibleAssetsIFRS", "CurrentYearInstant#{@c}")
        combined = [goodwill, intangible].compact.sum if goodwill || intangible
      end
      put(result, "bs.goodwill_and_intangibles", combined)
    end
end
```

### IfrsLiquidity（楽天・東京海上で実測済み）

分類系コード（bs.current_assets等）を含まない以外は IfrsClassified とほぼ同じ。
継承で差分定義せず**独立クラスとして定義する**（形式間に継承関係を作ると、片方の変更が
他方に波及して「形式ごとに独立して保守できる」利点が消えるため。重複はマッピング定数のみで許容）。

```ruby
# app/services/ingestion/extractors/ifrs_liquidity.rb
class Ingestion::Extractors::IfrsLiquidity < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.assets"                        => "jpigp_cor:AssetsIFRS",
    "bs.liabilities"                   => "jpigp_cor:LiabilitiesIFRS",
    "bs.equity"                        => "jpigp_cor:EquityIFRS",
    "bs.equity_attributable_to_owners" => "jpigp_cor:EquityAttributableToOwnersOfParentIFRS",
    "bs.non_controlling_interests"     => "jpigp_cor:NonControllingInterestsIFRS",
    "bs.cash_and_equivalents"          => "jpigp_cor:CashAndCashEquivalentsIFRS",
    "cf.cash_end"                      => "jpigp_cor:CashAndCashEquivalentsIFRS",
  }.freeze

  DURATION_MAPPING = Ingestion::Extractors::IfrsClassified::DURATION_MAPPING
  # PL/CFのタグ体系はBS形式と独立に共通（実測: 楽天・東京海上とも同一タグ）。
  # 意図的な共有であることをコメントで明示する。将来分岐したらコピーして独立させる

  private
    def extract_extras(result)
      put(result, "cf.cash_begin",
          @xbrl.money("jpigp_cor:CashAndCashEquivalentsIFRS", "Prior1YearInstant#{@c}"))
    end
end
```

## Ingestion::ReportIngester（オーケストレーション + 永続化）

```ruby
# app/services/ingestion/report_ingester.rb
module Ingestion
  class ReportIngester
    def initialize(client: Edinet::Client.new,
                   dei_extractor: DeiExtractor.new,
                   detector: FormatDetector.new)
      @client, @dei_extractor, @detector = client, dei_extractor, detector
    end

    # 1有報の取込。財務諸表がない書類（訂正のみ等）は何もしない
    def ingest(doc_id:, work_dir:)
      xbrl_path = @client.download_xbrl(doc_id: doc_id, work_dir: work_dir)
      return if xbrl_path.nil?

      xbrl = Xbrl::Document.load(xbrl_path)
      dei = @dei_extractor.extract(xbrl)
      return if dei.accounting_standard.nil?  # 基準不明はスキップ（Sentry警告を送る）

      statements = build_statements(xbrl, dei)
      persist(doc_id, dei, statements)
    ensure
      FileUtils.rm_f(xbrl_path) if xbrl_path
    end

    private
      Extraction = Struct.new(:consolidation_type, :accounting_standard, :format, :items, keyword_init: true)

      def build_statements(xbrl, dei)
        specs = []
        if dei.has_consolidated
          specs << [:consolidated, Extractors::Base::CONSOLIDATED,
                    dei.accounting_standard, dei.consolidated_industry_code]
        end
        # 単体は日本基準（IFRS有報でも実測どおりjppfs。US GAAP有報の単体も同様）
        specs << [:non_consolidated, Extractors::Base::NON_CONSOLIDATED,
                  "japan_gaap", dei.non_consolidated_industry_code]

        specs.map do |type, suffix, standard, industry|
          format = @detector.detect(xbrl, accounting_standard: standard,
                                    industry_code: industry, consolidation: suffix)
          extractor_class = FormatRegistry.extractor_for(format)
          items = extractor_class ? extractor_class.new(xbrl, suffix).extract : {}
          Extraction.new(consolidation_type: type, accounting_standard: standard,
                         format: format, items: items)
        end
      end

      # トランザクション境界は「1有報」: 途中失敗で企業だけ出来て財務諸表がない、等の
      # 中途半端な状態を残さない。有報間は独立（1件の失敗が他社に波及しない）
      def persist(doc_id, dei, statements)
        ActiveRecord::Base.transaction do
          # find_or_initialize + update! で作成/更新を同型に扱う（訂正有報・バックフィル
          # 再実行の冪等性）。自然キーはedinet_code（証券コードは変わり得るがEDINETコードは不変）
          company = Company.find_or_initialize_by(edinet_code: dei.edinet_code)
          company.update!(stock_code: dei.stock_code, name_ja: dei.name_ja, name_en: dei.name_en)

          # Reportの自然キーは (企業, 会計期間)。edinet_document_id ではない点に注意:
          # 訂正有報は別docIDで届くが「同じ期の報告書の上書き」として扱いたいため
          report = Report.find_or_initialize_by(
            company: company,
            fiscal_year_start_date: dei.fiscal_year_start_date,
            fiscal_year_end_date: dei.fiscal_year_end_date)
          report.update!(
            edinet_document_id: doc_id, filing_date: dei.filing_date,
            accounting_standard: dei.accounting_standard,
            has_consolidated_statement: dei.has_consolidated,
            consolidated_industry_code: dei.consolidated_industry_code,
            non_consolidated_industry_code: dei.non_consolidated_industry_code)

          statements.each do |ext|
            fs = FinancialStatement.find_or_initialize_by(
              report: report, consolidation_type: ext.consolidation_type)
            fs.update!(
              accounting_standard: ext.accounting_standard,
              presentation_format: ext.format,
              is_primary: primary?(ext, dei))
            # 科目は総入れ替え（delete→insert）。upsertにしない理由:
            # 「行の存在=開示あり」の規約のため、訂正で開示されなくなった科目は
            # 消えてもらう必要がある。upsertでは残留してしまう
            fs.items.delete_all
            rows = ext.items.map { |code, amount|
              { financial_statement_id: fs.id, item_code: code, amount: amount,
                created_at: Time.current, updated_at: Time.current } }
            # insert_all!はモデルのバリデーションを通らないため、item_codeの正当性は
            # Extractorのマッピング定数がItemCodes::ALLの範囲内であることをspecで担保する
            FinancialStatementItem.insert_all!(rows) if rows.any?
          end
        end
      end

      # is_primary = 一覧表示・検索の対象。投資判断では連結が重要のため連結を優先し、
      # 連結を作成しない企業のみ単体を主とする（現行アプリと同じ判断基準）
      def primary?(ext, dei)
        dei.has_consolidated ? ext.consolidation_type == :consolidated
                             : ext.consolidation_type == :non_consolidated
      end
  end
end
```

## 日次実行

```ruby
# app/services/ingestion/daily_ingestion_service.rb
module Ingestion
  class DailyIngestionService
    def self.run(from_date: Time.zone.yesterday, to_date: Time.zone.yesterday)
      client = Edinet::Client.new
      ingester = ReportIngester.new(client: client)
      Dir.mktmpdir("edinet") do |work_dir|
        (from_date.to_date..to_date.to_date).each do |date|
          client.list_annual_reports(date: date).each do |meta|
            # 1件の失敗を他に波及させない・レート制限のため同期逐次（現行実装の知見を踏襲）
            begin
              ingester.ingest(doc_id: meta.doc_id, work_dir: work_dir)
              Rails.logger.info("ingested #{meta.doc_id} #{meta.filer_name}")
            rescue => e
              Rails.logger.error("ingest failed #{meta.doc_id}: #{e.message}")
              Sentry.with_scope do |scope|
                scope.set_tags(document_id: meta.doc_id)
                Sentry.capture_exception(e)
              end
            end
          end
        rescue => e  # 一覧取得自体の失敗も日単位で隔離
          Sentry.capture_exception(e)
        end
      end
    end
  end
end

# app/jobs/daily_ingestion_job.rb
class DailyIngestionJob < ApplicationJob
  def perform = Ingestion::DailyIngestionService.run
end
```

## エラー処理ポリシー

- 失敗の隔離境界は「1書類」と「1日」（現行実装と同じ。Sentryタグも踏襲）
- `unsupported` 形式・科目が取れないことは**エラーではない**（行を作らないだけ）。
  ただし `is_primary` な財務諸表で `bs.assets` すら取れなかった場合は形式判定ミスの可能性が
  高いためSentryに警告イベントを送る（取込自体は継続）

## 層ごとの動作確認（実装しながら `rails c` で確かめる手順）

下から順に作る・確かめる。各層が前の層だけに依存するので、この順なら手戻りがない。

```ruby
# --- (1) Edinet::Client 単体 ---
client = Edinet::Client.new
metas = client.list_annual_reports(date: "2026-06-17")
metas.size            # 6月中旬なら数十〜数百件
metas.find { |m| m.doc_id == "S100YB5L" }  # 武田薬品が入っているはず（01の実測日）

require "tmpdir"
Dir.mktmpdir do |dir|
  path = client.download_xbrl(doc_id: "S100YB5L", work_dir: dir)
  puts File.size(path)  # 数MBのXBRLが展開される

  # --- (2) Xbrl::Document 単体 ---
  xbrl = Xbrl::Document.load(path)
  xbrl.money("jpigp_cor:AssetsIFRS", "CurrentYearInstant")    # => 15511506000000（01の実測値）
  xbrl.money("jppfs_cor:Assets", "CurrentYearInstant")        # => nil（IFRS企業の連結にjppfsはない）
  xbrl.text("jpdei_cor:AccountingStandardsDEI", "FilingDateInstant")  # => "IFRS"

  # --- (3) DeiExtractor / FormatDetector 単体 ---
  dei = Ingestion::DeiExtractor.new.extract(xbrl)
  dei.accounting_standard   # => "ifrs"
  Ingestion::FormatDetector.new.detect(
    xbrl, accounting_standard: "ifrs", industry_code: dei.consolidated_industry_code,
    consolidation: Ingestion::Extractors::Base::CONSOLIDATED)  # => "ifrs_classified"

  # --- (4) Extractor 単体 ---
  items = Ingestion::Extractors::IfrsClassified.new(xbrl, "").extract
  items["pl.revenue"]        # => 4505720000000
  items.key?("pl.gross_profit")  # => false（武田は非開示。キー自体がないのが正しい）
end

# --- (5) ReportIngester（DB書き込みまで通し） ---
Dir.mktmpdir { |dir| Ingestion::ReportIngester.new.ingest(doc_id: "S100YB5L", work_dir: dir) }
Report.last.primary_financial_statement.items_hash["bs.assets"]  # => 15511506000000
```

## Extractorのスペック実例（1件書けば残りは同型）

```ruby
# spec/services/ingestion/extractors/ifrs_classified_spec.rb
RSpec.describe Ingestion::Extractors::IfrsClassified do
  # fixtureは spec/support/fixtures/download_xbrl.rb で取得した実XBRL（06参照）
  let(:xbrl) { Xbrl::Document.load("spec/fixtures/xbrl/S100YB5L.xbrl") }

  describe "#extract（連結）" do
    subject(:items) { described_class.new(xbrl, Ingestion::Extractors::Base::CONSOLIDATED).extract }

    # 期待値は 01_xbrl_format_research.md の実測表から転記する。
    # 「なんとなく通る値」ではなく必ず実測表と突き合わせること（表の方が正）
    it "BS/PL/CFの骨格科目を実測値どおり抽出する" do
      expect(items).to include(
        "bs.assets"           => 15_511_506_000_000,
        "bs.equity"           => 7_430_649_000_000,
        "pl.revenue"          => 4_505_720_000_000,
        "pl.profit_before_tax" => -142_355_000_000,
        "cf.operating"        => 1_041_431_000_000,
        "cf.cash_begin"       => 385_113_000_000,
      )
    end

    it "のれんと無形資産を合算する（武田は別掲タグのため）" do
      expect(items["bs.goodwill_and_intangibles"]).to eq 5_809_010_000_000 + 3_419_348_000_000
    end

    it "非開示の科目はキー自体を作らない" do
      expect(items).not_to have_key("pl.gross_profit")       # 武田は売上総利益を開示しない
      expect(items).not_to have_key("pl.operating_expenses") # 営業費用一括型でもない
    end
  end
end
```

他形式のスペックも同じ構造で書く。**必ず入れるべき観点**:
`IfrsLiquidity`=分類系キーが無いこと（楽天）、`JgaapBank`=pl.revenueが無く
pl.ordinary_revenueがあること（三菱UFJ）、収益フォールバック=サマリタグで取れること（NTT）。
