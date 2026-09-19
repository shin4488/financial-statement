# 実XBRLフィクスチャ

Extractor系スペックの入力に使う実際の有報XBRL。1件数MBあるためgit管理せず、
必要なときに以下でEDINETから取得する（`EDINET_API_KEY` が必要）:

```bash
bundle exec rails runner '
  client = Edinet::Client.new
  dir = Rails.root.join("spec/fixtures/xbrl").to_s
  %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO S100YQ6Y S100YR8L
     S100YDJC S100YIHR S100YC7N S100YE63 S100Y9T5 S100Y90D S100XTDX S100YANQ S100YI2V
     S100YJB4 S100Y0DB S100YD29 S100YCL0 S100YE7T S100SO41
     S100XCO8 S100XTLJ S100YDP3 S100YGH5 S100YJHA
     S100YH8W S100YEGP S100YGFW S100YGOL S100YIW6 S100YGFN S100YZ8K S100YRHX S100YWE4].each do |doc_id|
    path = client.download_xbrl(doc_id: doc_id, work_dir: dir)
    puts "#{doc_id}: #{path}"
    sleep 2
  end
'
```

| docID | 企業 | 検証ポイント |
|---|---|---|
| S100YB5L | 武田薬品 | ifrs_classified / 税引前損失 / その他損益が費用側 / のれん+無形の別掲合算 |
| S100YB25 | 三菱商事 | ifrs_classified / その他損益が収益側 / のれん無形の合算タグ / Revenue2IFRS |
| S100YCP3 | NTT | ifrs_classified / 収益が企業拡張タグ→経営指標サマリでフォールバック |
| S100XTNW | 楽天グループ | ifrs_liquidity判定 / 営業費用一括 / 当期赤字 |
| S100YLS8 | 東京海上HD | ifrs_liquidity / PL表示不可（収益が標準タグに存在しない） |
| S100YJQO | 三菱UFJ FG | jgaap_bank判定（業種DEI=bnk） / 経常収益型PL / 営業CF巨額マイナス |
| S100YQ6Y | イオン | jgaap_general / 営業収益型（OperatingRevenue1・OperatingCostのペア優先） |
| S100YR8L | インスペック | jgaap_general / 単体のみ / 売上原価=当期製品製造原価（CostOfProductsManufactured） |
| S100YDJC | 大成建設 | 建設（cns）: 標準タグの売上高・売上原価・販管費で描ける |
| S100YIHR | 東京電力HD | 電気（ele）: 営業費用一括型 / 有形・無形の標準タグがなく固定資産1段 / 単体は営業損失 |
| S100YC7N | JR東日本 | 鉄道（単体rwy）: 事業区分別の営業収益・営業費の合算 / 全事業営業利益（OperatingIncomeTotalBusiness） |
| S100YE63 | 東急 | 鉄道（連結・単体ともrwy）: 連結は営業費の内訳（運輸業等営業費及び売上原価+販管費）と一括の併記 → 内訳優先 / 単体は営業原価 |
| S100Y9T5 | 沖縄セルラー電話 | 電気通信（elc）: 電気通信事業+附帯事業の合算 / 固定資産1段 |
| S100Y90D | 玉井商船 | 海運（wat）: 海運業+その他事業の合算 / 一般管理費（GeneralAndAdministrativeExpensesWAT） |
| S100XTDX | 静岡ガス | ガス（gas）: 供給販売費及び一般管理費（…GAS）/ 単体はガス事業・雑収益・附帯事業の全社売上を合算 |
| S100YANQ | いちよし証券 | 証券（sec）: 金融費用（pl.financial_expenses） |
| S100YI2V | アサックス | 特定金融（spf）: 営業費用一括に売上原価を併記 → 内訳では合わず一括で描く |
| S100YJB4 | 小林洋行 | 商品先物（cmd）: 売上原価 + 原価控除後の営業費用（OperatingExpensesCMD） / 単体は商品売上高より営業収益を優先 |
| S100Y0DB | Mマート | 投資業コード（inv）・単体のみ: 営業収益−汎用の営業費用（OperatingExpenses） |
| S100YD29 | かんぽ生命 | jgaap_insurance判定（連結・単体とも）/ 経常収益=OperatingIncomeINS / 保険契約準備金 |
| S100YCL0 | ソニーフィナンシャルG | 連結はjgaap_insurance / 単体は業種コードinsでも流動資産があるためjgaap_general |
| S100YE7T | 日本郵政 | 複数業種コード（bnk,ins）→ 先頭の銀行 / 貯金が企業拡張タグのためBSは描けない |
| S100SO41 | クリエイト・レストランツHD | ifrs_summary判定（2019年2月期=詳細タグ義務化前でjpigp_corが無い）/ 経営指標サマリからPL骨格+CF5点 |

期待値の出典はリポジトリルートの docs/guide/06_taxonomy_mapping.md（「実地調査の記録」）の実測表。
フィクスチャが存在しない場合、該当スペックはskipされる。

## ROE・ROAの追加サンプル

`spec/graphql/financial_indicators_samples_spec.rb` では上記と次の計33社・64財務諸表を、取込→DB→APIまで照合する。期待値にはExtractorとは別の経営指標サマリの金額・比率を使用する。銀行の比率の切捨て、ガス売上の内訳合算の丸め差は開示精度の範囲だけ許容する。

| docID | 企業 | 検証ポイント |
|---|---|---|
| S100XCO8 | ピクセラ | 損失・新株予約権、調整差額の省略 |
| S100XTLJ | キヤノン | 連結は米国基準で未対応、単体は日本基準で算出 |
| S100YDP3 | りそなHD | 銀行、高いレバレッジ、単体の調整差額nil |
| S100YGH5 | ソフトバンクG | IFRS、非支配持分と親会社帰属利益 |
| S100YJHA | ユニチカ | 期首の自己資本がマイナスでも平均がプラスのケース |
| S100YH8W | 東京ガス | ガスの連結・単体売上 |
| S100YEGP | 日本ガス | ガスの連結・単体売上 |
| S100YGFW | 東邦ガス | 内訳合算と売上総額の丸め差 |
| S100YGOL | 北海道ガス | 内訳合算と売上総額の丸め差 |
| S100YIW6 | 北陸ガス | ガスの連結・単体売上 |

- アサックスの初年度連結は期首残高がないため、開示ROEや単体の残高で代用しない。
- イオン単体の開示ROEは2.7%だが、このアプリの仕様（期首期末平均）では24,972 ÷ ((635,287 + 911,005) ÷ 2) = 3.2299…%。入力金額の一致と計算式を別途確認する。会社公表の比率に合わせて式を変えない。
- 三菱商事単体の収益は本表が標準の `jppfs_cor:Revenue`、サマリが企業拡張タグ。標準の本表から取得し、独自タグのサマリ金額とも照合する。

追加の回帰フィクスチャ `S100YGFN`（飯野海運単体）は、不動産事業の収益が企業拡張タグでも、標準サマリの全社売上116,888百万円で純利益率・回転率を算出することを検証する。海運事業だけの104,979百万円を全社売上にしない。

`S100YZ8K` はクレディセゾンを提出者とする信託受益証券の有報。提出者の証券コードが一覧APIにあっても企業自身の財務ではないため、一覧取得とdocID直接取込の両方で除外し、企業マスタを変更しないことを検証する。

`S100YRHX`（信金中央金庫）は、株主資本に相当する「会員勘定合計」が標準の `ShareholdersEquityShinkinBNK` で開示される例。連結・単体とも評価差額を加え、非支配持分を含めず期首・期末自己資本を取得することを検証する。

`S100YWE4`（丸井グループ）は、日本基準の収益が標準の `jppfs_cor:Revenue` で開示される例。収益276,862百万円を使い、売上関連の指標を欠損にしないことを検証する。
