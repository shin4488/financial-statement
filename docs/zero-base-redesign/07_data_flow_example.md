# データフロー実例 — 実データが各層をどう流れるか

実装者が各層の入出力を具体的にイメージできるよう、実測済みの2社
（**武田薬品 = IFRS流動/非流動・税引前赤字**、**三菱UFJ FG = 日本基準銀行**）のデータを
XBRL→Extractor→DB→ChartBuilder→GraphQL→画面まで通しで示す。
数値はすべて2026年提出有報からの実測値（単位: 円。表中は百万円）。

## 例1: 武田薬品工業（S100YB5L / ifrs_classified）

### (1) XBRLインスタンス上のfact（入力）

```xml
<jpigp_cor:CurrentAssetsIFRS contextRef="CurrentYearInstant" ...>3090503000000</jpigp_cor:CurrentAssetsIFRS>
<jpigp_cor:NonCurrentAssetsIFRS contextRef="CurrentYearInstant" ...>12421004000000</jpigp_cor:NonCurrentAssetsIFRS>
<jpigp_cor:AssetsIFRS contextRef="CurrentYearInstant" ...>15511506000000</jpigp_cor:AssetsIFRS>
<jpigp_cor:TotalCurrentLiabilitiesIFRS contextRef="CurrentYearInstant" ...>2832074000000</...>
<jpigp_cor:NonCurrentLabilitiesIFRS contextRef="CurrentYearInstant" ...>5248784000000</...>  <!-- 公式タイポ -->
<jpigp_cor:RevenueIFRS contextRef="CurrentYearDuration" ...>4505720000000</jpigp_cor:RevenueIFRS>
<jpigp_cor:ProfitLossBeforeTaxIFRS contextRef="CurrentYearDuration" ...>-142355000000</...>
<jpigp_cor:CashAndCashEquivalentsIFRS contextRef="Prior1YearInstant" ...>385113000000</...>   <!-- 期首 -->
```

ポイント: 同じ要素（例: CashAndCashEquivalentsIFRS）でも contextRef で期首/期末を区別する。
`Xbrl::Document` はこれを `[prefix, 要素名, contextRef] => 値` のハッシュに1パスで畳み込む。

### (2) FormatDetector の判定

```ruby
# accounting_standard="ifrs" かつ CurrentAssetsIFRS が実在 → :ifrs_classified
detector.detect(xbrl, accounting_standard: "ifrs", industry_code: "cte", consolidation: "")
# => "ifrs_classified"
```

### (3) Extractor 出力（`{item_code => amount}`。**取れない科目はキー自体がない**）

```ruby
Ingestion::Extractors::IfrsClassified.new(xbrl, "").extract
# => {
#   "bs.current_assets"                => 3_090_503_000_000,
#   "bs.non_current_assets"            => 12_421_004_000_000,
#   "bs.assets"                        => 15_511_506_000_000,
#   "bs.current_liabilities"           => 2_832_074_000_000,
#   "bs.non_current_liabilities"       => 5_248_784_000_000,
#   "bs.liabilities"                   => 8_080_858_000_000,
#   "bs.equity"                        => 7_430_649_000_000,
#   "bs.equity_attributable_to_owners" => 7_429_441_000_000,
#   "bs.non_controlling_interests"     => 1_208_000_000,
#   "bs.property_plant_and_equipment"  => 2_120_639_000_000,
#   "bs.goodwill_and_intangibles"      => 9_228_358_000_000,  # のれん5,809,010 + 無形3,419,348 を extract_extras で合算
#   "bs.cash_and_equivalents"          => 595_054_000_000,
#   "pl.revenue"                       => 4_505_720_000_000,  # RevenueIFRS が1番目のフォールバックでヒット
#   "pl.cost_of_sales"                 => 1_571_588_000_000,
#   "pl.sga"                           => 1_084_215_000_000,
#   "pl.operating_profit"              => 6_217_000_000,
#   "pl.profit_before_tax"             => -142_355_000_000,
#   "pl.income_tax"                    => 9_770_000_000,
#   "pl.profit"                        => -152_125_000_000,
#   "pl.profit_attributable_to_owners" => -152_390_000_000,
#   "cf.cash_begin"                    => 385_113_000_000,
#   "cf.operating"                     => 1_041_431_000_000,
#   "cf.investing"                     => -369_141_000_000,
#   "cf.financing"                     => -496_820_000_000,
#   "cf.cash_end"                      => 595_054_000_000,
# }
# 注: "pl.gross_profit" と "pl.operating_expenses" はキーがない（武田は本表で開示していないため）。
#     これはエラーではなく「開示なし」の正常表現
```

### (4) DBの行（financial_statements + financial_statement_items）

```
financial_statements:
  id=101, report_id=1, consolidation_type=consolidated, accounting_standard=ifrs,
  presentation_format="ifrs_classified", is_primary=true
  id=102, report_id=1, consolidation_type=non_consolidated, accounting_standard=japan_gaap,
  presentation_format="jgaap_general", is_primary=false   ← IFRS企業でも単体は日本基準

financial_statement_items:（id=101分の抜粋）
  | financial_statement_id | item_code            | amount             |
  | 101                    | bs.assets            |  15511506000000    |
  | 101                    | pl.revenue           |   4505720000000    |
  | 101                    | pl.profit_before_tax |   -142355000000    |
  | 101                    | cf.operating         |   1041431000000    |
  ...（(3)のハッシュがそのまま行になる。gross_profit の行は存在しない）
```

### (5) ChartBuilder（PlIfrs）の導出計算

```ruby
revenue        = 4_505_720  # 百万円表記
known_expenses = 1_571_588(原価) + 1_084_215(販管費) = 2_655_803
other_net      = pbt - (revenue - known_expenses)
               = -142_355 - (4_505_720 - 2_655_803) = -1_992_272
# → 負なので「その他損益（純額）」は借方（費用側）に絶対値1,992,272で積む
# pbt = -142,355 → 負なので「税引前損失」を貸方に絶対値142,355で積む
#
# 貸借検算（この導出により定義的に一致する。ここが導出項目を挟む意図）:
#   借方 1,571,588 + 1,084,215 + 1,992,272 = 4,648,075
#   貸方 4,505,720 + 142,355              = 4,648,075 ✓
```

### (6) GraphQLレスポンス（profitLoss部分。フロントが受け取る最終形）

```json
{
  "companyName": "武田薬品工業株式会社",
  "accountingStandard": "ifrs",
  "profitLoss": {
    "renderable": true,
    "note": null,
    "bars": [
      { "label": "借方", "segments": [
        { "key": "costOfSales",   "label": "売上原価",           "amount": 1571588000000, "signedAmount": 1571588000000,  "ratio": 34.8, "colorRole": "expense1" },
        { "key": "sga",           "label": "販売費及び一般管理費", "amount": 1084215000000, "signedAmount": 1084215000000,  "ratio": 24.0, "colorRole": "expense1" },
        { "key": "otherNet",      "label": "その他損益（純額）",   "amount": 1992272000000, "signedAmount": -1992272000000, "ratio": -44.2, "colorRole": "expense3" }
      ]},
      { "label": "貸方", "segments": [
        { "key": "revenue",       "label": "収益",               "amount": 4505720000000, "signedAmount": 4505720000000,  "ratio": 100.0, "colorRole": "revenue" },
        { "key": "lossBeforeTax", "label": "税引前損失",         "amount": 142355000000,  "signedAmount": -142355000000,  "ratio": -3.1,  "colorRole": "loss" }
      ]}
    ]
  }
}
```

`amount`（描画高さ・常に正）と `signedAmount`（実値・ツールチップ用）を分けているのが意図。
マイナス値を棒グラフに直接渡すと逆方向に描画されてしまう問題を、フロントではなく契約レベルで解決している。

### (7) 画面（フロントは上記JSONを機械的に積むだけ）

```
借方バー                     貸方バー
┌─────────────┐    ┌─────────────┐
│ 売上原価 34.8%      │    │ 収益 100%           │
├─────────────┤    │                     │
│ 販管費 24.0%        │    │                     │
├─────────────┤    │                     │
│ その他損益(純額)     │    ├─────────────┤
│ -44.2%              │    │ 税引前損失 -3.1%    │
└─────────────┘    └─────────────┘
```

## 例2: 三菱UFJ FG（S100YJQO / jgaap_bank）— 同じ契約に別形式が乗る例

### Extractor出力（抜粋）

```ruby
# => {
#   "bs.assets"               => 431_731_548_000_000,  # 431兆円。Int32はもちろんJSのInt32も超える→BigInt採用の理由
#   "bs.cash_and_equivalents" =>  90_045_500_000_000,  # 現金預け金
#   "bs.loans"                => 133_799_490_000_000,
#   "bs.securities"           =>  85_714_795_000_000,
#   "bs.deposits"             => 239_439_246_000_000,
#   "bs.liabilities"          => 407_987_396_000_000,
#   "bs.equity"               =>  23_744_152_000_000,
#   "pl.ordinary_revenue"     =>  14_620_843_000_000,  # 経常収益（pl.revenueはキー自体なし）
#   "pl.ordinary_expenses"    =>  11_210_651_000_000,
#   "pl.ordinary_profit"      =>   3_410_192_000_000,
#   "cf.cash_begin"           => 109_095_437_000_000,
#   "cf.operating"            => -23_064_420_000_000,  # 銀行は営業CFが巨額の負になり得る
#   ...
# }
```

### ChartBuilder（BsJgaapBank）の導出

```ruby
other_assets      = 431_731_548 - (90_045_500 + 133_799_490 + 85_714_795) = 122_171_763
other_liabilities = 407_987_396 - 239_439_246 = 168_548_150
# 「その他」を残差で導出する意図: 銀行の内訳科目は多数あり全列挙は保守コストが高い。
# 分析上意味の大きい科目（貸出金・有価証券・預金）だけ実タグで取り、残りは合計からの差分で吸収する
```

### GraphQLレスポンス（balanceSheet部分）

```json
{ "balanceSheet": { "renderable": true, "bars": [
  { "label": "借方", "segments": [
    { "key": "cash",        "label": "現金預け金", "amount": 90045500000000,  "ratio": 20.8, "colorRole": "asset1" },
    { "key": "loans",       "label": "貸出金",     "amount": 133799490000000, "ratio": 30.9, "colorRole": "asset2" },
    { "key": "securities",  "label": "有価証券",   "amount": 85714795000000,  "ratio": 19.8, "colorRole": "asset3" },
    { "key": "otherAssets", "label": "その他資産", "amount": 122171763000000, "ratio": 28.2, "colorRole": "asset4" }
  ]},
  { "label": "貸方", "segments": [
    { "key": "deposits",         "label": "預金",     "amount": 239439246000000, "ratio": 55.4, "colorRole": "liability1" },
    { "key": "otherLiabilities", "label": "その他負債", "amount": 168548150000000, "ratio": 39.0, "colorRole": "liability2" },
    { "key": "equity",           "label": "純資産",   "amount": 23744152000000,  "ratio": 5.4,  "colorRole": "equity" }
  ]}
]}}
```

**フロントから見ると例1と完全に同じ構造**（segmentsのkey/labelが違うだけ）。
これが「形式の違いをバックエンドの契約で吸収し、フロントは1コンポーネントで済む」の実体。

### CFの補足（為替影響差異）

```
期首 109,095,437 + 営業(-23,064,420) + 投資(+4,473,959) + 財務(-1,149,876) = 89,355,100
実際の期末                                                              = 90,045,500（差690,400 = 為替換算差額）
```

CF計算書には「現金及び現金同等物に係る換算差額」があるため3区分の合計と期首期末は一致しない。
`WaterfallStep.kind = "balance"` の期末残高を**0起点で独立に描く**設計はこの差異を吸収する意図
（累積位置で描くと期末バーが実際の残高とずれる）。

## 例3: 表示不可の正常系（東京海上HD / ifrs_liquidity）

```ruby
items["pl.revenue"]  # => nil（保険収益は企業拡張タグのみ。標準タグにもサマリにも存在しない）
# → PlIfrs#build が StackChart.unrenderable(...) を返す

# GraphQL:
{ "profitLoss": { "renderable": false,
    "note": "損益計算書: この企業のIFRS損益計算書は表示に対応していません。", "bars": [] },
  "balanceSheet": { "renderable": true, ... },   # BSとCFは普通に表示できる
  "cashFlow": { "renderable": true, ... } }
```

「表示できない」を例外やnullではなく `renderable: false + note` という**第一級のデータ**として
扱う意図: 3表のうち1表だけ欠ける実例（東京海上）があるため、カード全体を落とさず
チャート単位で劣化させる必要がある。フロントの分岐は `renderable` の1個だけになる。
