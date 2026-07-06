# バックエンド実装詳細 — 表示層（Charts / GraphQL）

> Builderの導出計算（その他損益純額・銀行のその他資産残差など）とGraphQLレスポンスの
> 実データ例は [07_data_flow_example.md](07_data_flow_example.md) を併読すること。
> 特にPlIfrsの貸借一致の検算例（武田: 借方4,648,075 = 貸方4,648,075百万円）は
> テストの期待値としてそのまま使える。

## 設計方針

- バックエンドが**チャートの構造そのもの**（積み上げバーとセグメントの列）を組み立てて返す。
  フロントは科目・会計基準・形式を一切知らず、受け取った構造を描くだけ
- 比率・導出値（その他損益純額、その他資産など）はここで計算する（DBには事実のみ）
- 債務超過・赤字の表示反転、貸借バリデーションは**基底クラスの汎用処理**に集約し、
  形式別Builderは「どの科目をどの順でどちら側に積むか」の宣言に近づける

## ディレクトリ構成

```
app/services/charts/
  structs.rb            # Segment / Bar / StackChart / WaterfallStep / WaterfallChart
  builder_registry.rb   # presentation_format → Builderの対応表
  builders/
    stack_base.rb       # 貸借2本積み上げの汎用ロジック（比率・債務超過・検証）
    bs_jgaap_general.rb
    bs_jgaap_bank.rb
    bs_ifrs_classified.rb
    bs_ifrs_liquidity.rb
    pl_jgaap_general.rb
    pl_jgaap_bank.rb
    pl_ifrs.rb          # IFRSはBS形式によらずPLは共通ロジック（科目の実在で分岐）
    cash_flow.rb        # 全形式共通
app/graphql/
  types/ ...            # 後述
app/services/reports/
  search_query.rb       # 一覧検索
```

## データ構造（structs.rb）

```ruby
module Charts
  # amount: 描画高さ（常に0以上） / signed_amount: 実際の値（ツールチップ表示用）
  # color_role: フロントのパレット対応キー（後述の固定enum）
  Segment = Struct.new(:key, :label, :amount, :signed_amount, :ratio, :color_role, keyword_init: true)
  Bar = Struct.new(:label, :segments, keyword_init: true)
  StackChart = Struct.new(:renderable, :note, :bars, keyword_init: true) do
    def self.unrenderable(note) = new(renderable: false, note: note, bars: [])
  end

  WaterfallStep = Struct.new(:key, :label, :amount, :kind, keyword_init: true)  # kind: "balance" | "flow"
  WaterfallChart = Struct.new(:renderable, :note, :steps, keyword_init: true) do
    def self.unrenderable(note) = new(renderable: false, note: note, steps: [])
  end
end
```

`color_role` の値（固定enum。フロントと共有する契約）:
`asset1 asset2 asset3 asset4 liability1 liability2 equity revenue expense1 expense2 expense3 profit loss spacer`

## 汎用基底（builders/stack_base.rb）

```ruby
module Charts
  module Builders
    class StackBase
      RATIO_PRECISION = 3
      # 貸借の許容乖離1割（現行アプリの実績値を踏襲）。超えたら「未対応の様式か取込不良」と
      # みなして描画しない。誤ったグラフを出すより出さない方がよい、という安全側の判断
      TOLERANCE = 0.1

      def initialize(items)
        @items = items  # {item_code => amount} (FinancialStatement#items_hash)
      end

      private
        def val(code) = @items[code]

        # 比率は%値（0-100）。truncate（切り捨て）を使う理由: 四捨五入だと内訳の合計が
        # 100%を超えて表示され得る（現行アプリ踏襲）。合計を厳密に100にしたい場合は
        # 呼び出し側で「最後の1項目=100-他項目の合計」とする（BsJgaapGeneralの現行手法）
        def ratio(value, base)
          return nil if base.nil? || base.zero? || value.nil?
          (value.to_d / base).truncate(RATIO_PRECISION).to_f * 100
        end

        # Segmentの生成規約:
        #   amount       = 描画高さ。絶対値（rechartsに負を渡すと棒が逆向きに描かれるため）
        #   signed_amount= 実値。ツールチップ表示用。signed引数で明示指定がなければamountと同じ
        #   ratio        = signed基準で計算（損失なら負の%になり「-3.1%」と表示される）
        def seg(key, label, amount, role, base:, signed: nil)
          Segment.new(key: key, label: label, amount: amount.abs,
                      signed_amount: signed || amount, ratio: ratio(signed || amount, base),
                      color_role: role)
        end

        # 貸借2本構成の共通組み立て:
        # - specs: [key, label, item_code or 金額, color_role] の配列。金額nilの科目はスキップ
        # - equity(資本・純資産)が負なら3本目バー（spacer + 資本のマイナス表示）
        # - 貸借合計の乖離がTOLERANCE超なら描画不可
        # 債務超過表示・貸借検証は形式によらず同じ問題なので、ここに1回だけ実装する
        # （形式別Builderに書かせない = 新形式追加時にこのロジックの再実装漏れが起きない）
        def two_sided_chart(debit_specs:, credit_specs:, equity:, equity_label:, base:, unrenderable_note:)
          debit = build_segments(debit_specs, base)
          credit = build_segments(credit_specs, base)
          return StackChart.unrenderable(unrenderable_note) if debit.empty? || equity.nil?

          bars = [Bar.new(label: "借方", segments: debit)]
          if equity.negative?
            # 債務超過: 貸方は負債のみ（負債合計 > 資産合計の状態）。3本目のバーで
            # 「資産と負債の差 = マイナスの純資産」を可視化する。
            # spacer = 資産合計と同じ高さまで透明で詰めて、負債を超えた部分にだけ
            # 赤いセグメントが現れるようにする位置合わせ（現行アプリと同じ表現）
            bars << Bar.new(label: "貸方", segments: credit)
            spacer_amount = credit.sum(&:amount) + equity  # = 負債合計 - |純資産| = 資産合計
            bars << Bar.new(label: "債務超過", segments: [
              seg("spacer", "", spacer_amount, "spacer", base: nil),  # base:nil → ratio非表示
              seg("equity", equity_label, -equity, "loss", base: base, signed: equity),
            ])
          else
            bars << Bar.new(label: "貸方",
                            segments: credit + [seg("equity", equity_label, equity, "equity", base: base)])
          end

          debit_total = debit.sum(&:amount)
          credit_total = bars.drop(1).flat_map(&:segments).sum { |s| s.signed_amount }
          unless balanced?(debit_total, credit_total)
            return StackChart.unrenderable(unrenderable_note)
          end
          StackChart.new(renderable: true, note: nil, bars: bars)
        end

        def build_segments(specs, base)
          specs.filter_map do |key, label, code_or_value, role|
            value = code_or_value.is_a?(String) ? val(code_or_value) : code_or_value
            next if value.nil?
            seg(key, label, value, role, base: base)
          end
        end

        def balanced?(debit_total, credit_total)
          return false if debit_total.zero?
          (credit_total - debit_total).abs <= debit_total * TOLERANCE
        end
    end
  end
end
```

## BS Builder（形式別）

```ruby
class Charts::Builders::BsJgaapGeneral < Charts::Builders::StackBase
  def build
    # 比率の分母をbs.assetsでなく「表示する4科目の合計」にする理由（現行アプリ踏襲）:
    # jppfs_cor:Assetsには繰延資産など表示しない科目も含まれ得るため、
    # bs.assetsを分母にすると表示セグメントの比率合計が100%に届かない企業が出る。
    # 表示するものの合計を分母にすれば定義上100%で完結する
    base = %w[bs.current_assets bs.tangible_fixed_assets
              bs.intangible_fixed_assets bs.investments_and_other_assets].sum { |c| val(c).to_i }
    two_sided_chart(
      debit_specs: [
        ["currentAssets",  "流動資産",     "bs.current_assets",               "asset1"],
        ["tangible",       "有形固定資産", "bs.tangible_fixed_assets",        "asset2"],
        ["intangible",     "無形固定資産", "bs.intangible_fixed_assets",      "asset3"],
        ["investments",    "投資その他資産", "bs.investments_and_other_assets", "asset4"],
      ],
      credit_specs: [
        ["currentLiabilities", "流動負債", "bs.current_liabilities",     "liability1"],
        ["fixedLiabilities",   "固定負債", "bs.non_current_liabilities", "liability2"],
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: base,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end
end

class Charts::Builders::BsIfrsClassified < Charts::Builders::StackBase
  def build
    two_sided_chart(
      debit_specs: [
        ["currentAssets",    "流動資産",   "bs.current_assets",     "asset1"],
        ["nonCurrentAssets", "非流動資産", "bs.non_current_assets", "asset2"],
      ],
      credit_specs: [
        ["currentLiabilities",    "流動負債",   "bs.current_liabilities",     "liability1"],
        ["nonCurrentLiabilities", "非流動負債", "bs.non_current_liabilities", "liability2"],
      ],
      equity: val("bs.equity"), equity_label: "資本", base: val("bs.assets"),
      unrenderable_note: "財政状態計算書: データがない、または表示対応していないデータです。")
  end
end

class Charts::Builders::BsIfrsLiquidity < Charts::Builders::StackBase
  # 流動性配列: 区分がないため「現金及び現金同等物 + その他資産（導出）」の2段で表現
  def build
    assets = val("bs.assets")
    cash = val("bs.cash_and_equivalents")
    other_assets = assets && cash ? assets - cash : nil
    two_sided_chart(
      debit_specs: [
        ["cash",        "現金及び現金同等物", cash,         "asset1"],
        ["otherAssets", "その他資産",         other_assets, "asset2"],
      ],
      credit_specs: [
        ["liabilities", "負債", "bs.liabilities", "liability1"],
      ],
      equity: val("bs.equity"), equity_label: "資本", base: assets,
      unrenderable_note: "財政状態計算書: データがない、または表示対応していないデータです。")
  end
end

class Charts::Builders::BsJgaapBank < Charts::Builders::StackBase
  # 銀行: 分析の定番である貸出金・有価証券・現金預け金 + 預金を内訳表示（01の実測タグ）
  def build
    assets = val("bs.assets")
    known_assets = %w[bs.cash_and_equivalents bs.loans bs.securities].sum { |c| val(c).to_i }
    other_assets = assets ? assets - known_assets : nil
    liabilities = val("bs.liabilities")
    other_liabilities = liabilities && val("bs.deposits") ? liabilities - val("bs.deposits") : liabilities
    two_sided_chart(
      debit_specs: [
        ["cash",        "現金預け金", "bs.cash_and_equivalents", "asset1"],
        ["loans",       "貸出金",     "bs.loans",                "asset2"],
        ["securities",  "有価証券",   "bs.securities",           "asset3"],
        ["otherAssets", "その他資産", other_assets,              "asset4"],
      ],
      credit_specs: [
        ["deposits",         "預金",       "bs.deposits",     "liability1"],
        ["otherLiabilities", "その他負債", other_liabilities, "liability2"],
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: assets,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end
end
```

## PL Builder（形式別）

PLは貸借バランスが定義的に成立する（導出項目が差分を埋める）ため、
`two_sided_chart` は使わずBuilderごとに組み立てる。共通ヘルパ（`seg`/`ratio`）のみ利用。

```ruby
class Charts::Builders::PlJgaapGeneral < Charts::Builders::StackBase
  # 現行アプリと同じ構成: 借方[原価, 販管費, 営業利益] / 貸方[売上高(, 営業損失)]
  def build
    revenue = val("pl.revenue")
    op = val("pl.operating_profit")
    # 売上高と営業利益は日本基準一般の実質必須科目。無い=形式不一致か取込不良なので描画しない
    return StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。") if revenue.nil? || revenue.zero? || op.nil?

    debit = [
      # 原価・販管費は .to_i でnil→0に倒す（現行アプリ互換）: 原価を持たない持株会社等でも
      # 「売上と営業利益だけの構成」で描画を継続する。IFRS（PlIfrs）と違い導出項目を挟まないのは、
      # 日本基準では 売上-原価-販管費=営業利益 が制度上ほぼ成立し、残差処理が不要なため
      seg("costOfSales", "売上原価",   val("pl.cost_of_sales").to_i, "expense1", base: revenue),
      seg("sga",         "販売一般管理費", val("pl.sga").to_i,       "expense2", base: revenue),
    ]
    credit = [seg("revenue", "売上", revenue, "revenue", base: revenue)]
    if op.negative?
      credit << seg("operatingLoss", "営業損失", -op, "loss", base: revenue, signed: op)
    else
      debit << seg("operatingProfit", "営業利益", op, "profit", base: revenue)
    end
    StackChart.new(renderable: true, note: nil,
                   bars: [Bar.new(label: "借方", segments: debit), Bar.new(label: "貸方", segments: credit)])
  end
end

class Charts::Builders::PlJgaapBank < Charts::Builders::StackBase
  # 銀行: 借方[経常費用, 経常利益] / 貸方[経常収益(, 経常損失)]
  def build
    revenue = val("pl.ordinary_revenue")
    expenses = val("pl.ordinary_expenses")
    profit = val("pl.ordinary_profit")
    return StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。") if revenue.nil? || expenses.nil? || profit.nil?

    debit = [seg("ordinaryExpenses", "経常費用", expenses, "expense1", base: revenue)]
    credit = [seg("ordinaryRevenue", "経常収益", revenue, "revenue", base: revenue)]
    if profit.negative?
      credit << seg("ordinaryLoss", "経常損失", -profit, "loss", base: revenue, signed: profit)
    else
      debit << seg("ordinaryProfit", "経常利益", profit, "profit", base: revenue)
    end
    StackChart.new(renderable: true, note: nil,
                   bars: [Bar.new(label: "借方", segments: debit), Bar.new(label: "貸方", segments: credit)])
  end
end

class Charts::Builders::PlIfrs < Charts::Builders::StackBase
  # IFRS: 収益→税引前利益の骨格。費用の内訳は「ある科目だけ」使い、残差は「その他損益（純額）」
  # 検算済みの実例（01参照）:
  #   武田:     借方[原価, 販管費, その他費用純額, ] 貸方[収益, 税引前損失]
  #   三菱商事: 借方[原価, 販管費, 税引前利益]      貸方[収益, その他収益純額]
  #   楽天:     借方[営業費用, その他費用純額]       貸方[収益, 税引前損失]
  #   東京海上: 収益が取得不可 → 表示不可（正常系）
  def build
    revenue = val("pl.revenue")
    pbt = val("pl.profit_before_tax")
    return StackChart.unrenderable("損益計算書: この企業のIFRS損益計算書は表示に対応していません。") if revenue.nil? || revenue.zero? || pbt.nil?

    # 費用の内訳は「開示されている科目だけ」使う。
    # 武田型=原価+販管費 / 楽天・NTT型=営業費用一括、のどちらでもこの1つのリストで吸収できる
    # （原価/販管費と営業費用一括が同時に開示される企業は想定しない。両方あれば両方積まれるが
    #   その場合はother_netが差分を吸収するので貸借は崩れない）
    expense_specs = [
      ["costOfSales",       "売上原価",           val("pl.cost_of_sales"),      "expense1"],
      ["sga",               "販売費及び一般管理費", val("pl.sga"),                "expense2"],
      ["operatingExpenses", "営業費用",           val("pl.operating_expenses"), "expense1"],
    ].reject { |_, _, v, _| v.nil? }
    known_expenses = expense_specs.sum { |_, _, v, _| v }
    # その他損益（純額）= 開示された科目だけでは説明できない差分。
    # 内容は「その他営業損益 + 金融損益 + 持分法損益 等の純額」（正=収益側 / 負=費用側）。
    # この導出項目が差分を全部引き受けるため、借方合計=貸方合計が定義的に成立する
    # （検算例は07: 武田 4,648,075 = 4,648,075 百万円）
    other_net = pbt - (revenue - known_expenses)

    debit = expense_specs.map { |key, label, v, role| seg(key, label, v, role, base: revenue) }
    credit = [seg("revenue", "収益", revenue, "revenue", base: revenue)]
    if other_net.negative?
      debit << seg("otherNet", "その他損益（純額）", -other_net, "expense3", base: revenue, signed: other_net)
    elsif other_net.positive?
      credit << seg("otherNet", "その他損益（純額）", other_net, "revenue", base: revenue)
    end
    # other_net.zero? の場合はセグメント自体を出さない（高さ0の積み上げは無意味なため）
    if pbt.negative?
      # 赤字は貸方に「税引前損失」として積む: 借方（費用）が貸方（収益）より高いとき、
      # その差を貸方側に埋めることで2本の高さを揃える（日本基準の営業損失と同じ表現）
      credit << seg("lossBeforeTax", "税引前損失", -pbt, "loss", base: revenue, signed: pbt)
    else
      debit << seg("profitBeforeTax", "税引前利益", pbt, "profit", base: revenue)
    end
    StackChart.new(renderable: true, note: nil,
                   bars: [Bar.new(label: "借方", segments: debit), Bar.new(label: "貸方", segments: credit)])
  end
end
```

## CF Builder（全形式共通）

```ruby
class Charts::Builders::CashFlow < Charts::Builders::StackBase
  STEPS = [
    ["cashBegin", "期首残高",                 "cf.cash_begin", "balance"],
    ["operating", "営業活動によるキャッシュフロー", "cf.operating",  "flow"],
    ["investing", "投資活動によるキャッシュフロー", "cf.investing",  "flow"],
    ["financing", "財務活動によるキャッシュフロー", "cf.financing",  "flow"],
    ["cashEnd",   "期末残高",                 "cf.cash_end",   "balance"],
  ].freeze

  def build
    # 5点すべて揃わなければ表示不可とする（all-or-nothing）。
    # 理由: ウォーターフォールは1点欠けると滝の繋がりが崩れ、誤解を招くグラフになる。
    # 実測では6社全社で5点揃った（01参照）ため、欠けるのは単体のみ開示など特殊ケースに限られる
    steps = STEPS.map { |key, label, code, kind|
      v = val(code)
      return WaterfallChart.unrenderable("キャッシュフロー: データがない、または表示対応していないデータです。") if v.nil?
      WaterfallStep.new(key: key, label: label, amount: v, kind: kind)
    }
    WaterfallChart.new(renderable: true, note: nil, steps: steps)
  end
end
```

（`amount` はStackChartと違い**符号付きのまま**渡す。増減の向きが情報そのものだから。
浮かせ方・為替差異の吸収はフロント側 `toRows` の責務 — [05](05_frontend.md) §6参照）

## BuilderRegistry

```ruby
module Charts
  module BuilderRegistry
    BS = {
      "jgaap_general"   => Builders::BsJgaapGeneral,
      "jgaap_bank"      => Builders::BsJgaapBank,
      "ifrs_classified" => Builders::BsIfrsClassified,
      "ifrs_liquidity"  => Builders::BsIfrsLiquidity,
    }.freeze
    PL = {
      "jgaap_general"   => Builders::PlJgaapGeneral,
      "jgaap_bank"      => Builders::PlJgaapBank,
      "ifrs_classified" => Builders::PlIfrs,   # IFRSのPLはBS形式に依存しない（01参照）
      "ifrs_liquidity"  => Builders::PlIfrs,
    }.freeze
    UNSUPPORTED_NOTE = "この会計基準・業種の財務諸表は表示に対応していません。".freeze

    def self.build_all(financial_statement)
      items = financial_statement.items_hash
      format = financial_statement.presentation_format
      {
        balance_sheet: BS[format]&.new(items)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        profit_loss:   PL[format]&.new(items)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        cash_flow:     Builders::CashFlow.new(items).build,
      }
    end
  end
end
```

## 検索（reports/search_query.rb）

```ruby
module Reports
  class SearchQuery
    CF_CODES = {
      operating: "cf.operating", investing: "cf.investing", financing: "cf.financing",
    }.freeze

    # cf_signs: { operating: :positive|:negative|nil, ... }
    def call(limit:, offset:, stock_codes: nil, cf_signs: {})
      scope = Report.joins(:primary_financial_statement)
                    .includes(:company, primary_financial_statement: :items)
                    .order(Report.arel_table[:filing_date].desc.nulls_last,
                           fiscal_year_end_date: :desc, updated_at: :desc)
                    .limit(limit).offset(offset)
      if stock_codes.present?
        # 証券コードはEDINET上5桁。UIは4桁入力のため0パディング（現行仕様踏襲）
        scope = scope.joins(:company).where(companies: { stock_code: stock_codes.map { |c| "#{c}0" } })
      end
      cf_signs.compact.each do |key, sign|
        # opの文字列埋め込みはSQLインジェクション安全: :positive/:negative の2値からしか
        # 生成されない（GraphQL enumで制約済み）。item_codeの方はユーザ入力経路がないが
        # 一貫性のためプレースホルダでバインドする
        op = sign == :positive ? ">" : "<"
        scope = scope.where(<<~SQL, CF_CODES.fetch(key))
          EXISTS (SELECT 1 FROM financial_statement_items i
                  WHERE i.financial_statement_id = financial_statements.id
                    AND i.item_code = ? AND i.amount #{op} 0)
        SQL
      end
      scope
    end
  end
end
```

（EXISTSサブクエリは `idx_items_code_amount`（item_code, amount複合インデックス・02参照）で
インデックスオンリーに近い評価になる。符号条件を追加するたびにEXISTSが1つ増えるが最大3つ）

## GraphQL

金額は資産431兆（MUFG実測）などInt32を超えるため `GraphQL::Types::BigInt` を使う。

```ruby
module Types
  class SegmentType < BaseObject
    field :key, String, null: false
    field :label, String, null: false
    field :amount, GraphQL::Types::BigInt, null: false          # 描画高さ（>=0）
    field :signed_amount, GraphQL::Types::BigInt, null: false   # 実値（ツールチップ用）
    field :ratio, Float, null: true                             # %（spacer等はnull）
    field :color_role, String, null: false
  end

  class StackBarType < BaseObject
    field :label, String, null: false
    field :segments, [SegmentType], null: false
  end

  class StackChartType < BaseObject
    field :renderable, Boolean, null: false
    field :note, String, null: true
    field :bars, [StackBarType], null: false
  end

  class WaterfallStepType < BaseObject
    field :key, String, null: false
    field :label, String, null: false
    field :amount, GraphQL::Types::BigInt, null: false
    field :kind, String, null: false  # "balance" | "flow"
  end

  class WaterfallChartType < BaseObject
    field :renderable, Boolean, null: false
    field :note, String, null: true
    field :steps, [WaterfallStepType], null: false
  end

  class FinancialReportType < BaseObject
    field :id, ID, null: false
    field :stock_code, String, null: true          # 4桁化して返す（末尾0を落とす）
    field :company_name, String, null: true
    field :fiscal_year_start_date, String, null: false
    field :fiscal_year_end_date, String, null: false
    field :filing_date, String, null: true
    field :accounting_standard, String, null: false      # 表示中の財務諸表の基準（バッジ表示用）
    field :consolidation_type, String, null: false       # "consolidated" | "non_consolidated"
    field :presentation_format, String, null: false
    field :balance_sheet, StackChartType, null: false
    field :profit_loss, StackChartType, null: false
    field :cash_flow, WaterfallChartType, null: false
  end

  class NumberSignType < BaseEnum
    value "POSITIVE", value: :positive
    value "NEGATIVE", value: :negative
  end

  class QueryType < BaseObject
    field :financial_reports, [FinancialReportType], null: false do
      argument :limit, Integer, required: true, validates: { numericality: { greater_than: 0, less_than_or_equal_to: 100 } }
      argument :offset, Integer, required: true, validates: { numericality: { greater_than_or_equal_to: 0 } }
      argument :stock_codes, [String], required: false
      argument :operating_cf_sign, NumberSignType, required: false
      argument :investing_cf_sign, NumberSignType, required: false
      argument :financing_cf_sign, NumberSignType, required: false
    end

    def financial_reports(limit:, offset:, stock_codes: nil,
                          operating_cf_sign: nil, investing_cf_sign: nil, financing_cf_sign: nil)
      reports = Reports::SearchQuery.new.call(
        limit: limit, offset: offset, stock_codes: stock_codes,
        cf_signs: { operating: operating_cf_sign, investing: investing_cf_sign, financing: financing_cf_sign })
      reports.map { |report| present(report) }
    end

    private
      def present(report)
        fs = report.primary_financial_statement
        charts = Charts::BuilderRegistry.build_all(fs)
        {
          id: report.id,
          # EDINETの証券コードは5桁（4桁コード+チェック用の末尾"0"）。UI・世間の慣習は4桁なので
          # API境界で4桁に変換して返す（DBには5桁のまま保存し、検索時は逆に"0"を付ける）
          stock_code: report.company.stock_code&.delete_suffix("0"),
          company_name: report.company.name_ja,
          fiscal_year_start_date: report.fiscal_year_start_date.to_s,
          fiscal_year_end_date: report.fiscal_year_end_date.to_s,
          filing_date: report.filing_date&.to_s,
          accounting_standard: fs.accounting_standard,
          consolidation_type: fs.consolidation_type,
          presentation_format: fs.presentation_format,
          **charts,
        }
      end
  end
end
```

## テスト方針（表示層）

- Builderは純関数（`{item_code=>amount}` → Struct）なのでDBなしの単体テストで網羅する。
  01の実測値をそのままfixtureにする:
  - `PlIfrs`: 武田（税引前損失・その他費用純額）/ 三菱商事（その他収益純額）/ 楽天（営業費用一括）/
    revenueなし（東京海上相当）→ unrenderable
  - `Bs*`: 債務超過ケース（equity負値の合成データ）、貸借1割乖離 → unrenderable
  - `CashFlow`: 5値そろい / cash_begin欠け → unrenderable
- `SearchQuery` はDBありで: is_primary絞り込み、CF符号のEXISTS、証券コード0パディング
