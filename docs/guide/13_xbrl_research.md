# 13. XBRL実地調査結果（6社・4形式）

EDINET API v2 で実際に有報XBRLを取得し、全factをダンプして分析した結果。調査当時の旧系統実装（`SecurityReport::ReaderRepository`）の実行結果とも突き合わせている。
タクソノミの公式資料だけでは分からない実態（公式のタイポ・企業拡張タグしか無い企業・
様式ごとのタグ欠落）が実装判断を左右するため、実物での確認記録を残している。

## 調査対象

| 企業 | 証券コード | docID | 会計基準(DEI) | 連結業種(DEI) | 判定形式 |
|---|---|---|---|---|---|
| 武田薬品工業 | 4502 | S100YB5L | IFRS | cte | ifrs_classified |
| 三菱商事 | 8058 | S100YB25 | IFRS | cte | ifrs_classified |
| ＮＴＴ | 9432 | S100YCP3 | IFRS | cte | ifrs_classified |
| 楽天グループ | 4755 | S100XTNW | IFRS | cte | ifrs_liquidity |
| 東京海上HD | 8766 | S100YLS8 | IFRS | **INS** | ifrs_liquidity |
| 三菱UFJ FG | 8306 | S100YJQO | Japan GAAP | **bnk** | jgaap_bank |

- いずれも2026年提出の有報（武田・三菱商事・NTT・MUFG・東京海上=2026/3期、楽天=2025/12期）。
- 東京海上HDは2026/3期からIFRSへ移行済みだった（当初は日本基準保険業のサンプルとして選定）。
  そのため**日本基準・保険業の実測サンプルは未取得**。将来対応時に実測すること。

## 形式ごとの構造（実測）

### 共通事項（全6社）

- コンテキストID体系は全形式共通:
  連結=`CurrentYearInstant` / `CurrentYearDuration` / `Prior1YearInstant`（サフィックスなし）、単体=`〜_NonConsolidatedMember`。
- DEI（`jpdei_cor`）は全形式共通に取得可能:
  `AccountingStandardsDEI`（"Japan GAAP"/"US GAAP"/"IFRS"）、`EDINETCodeDEI`、`SecurityCodeDEI`、`CurrentFiscalYearStartDateDEI`/`EndDateDEI`、`WhetherConsolidatedFinancialStatementsArePreparedDEI`、`IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI`（例: cte/bnk/INS）。
- **IFRS企業の単体財務諸表は日本基準**（`jppfs_cor` + `_NonConsolidatedMember`）で全社タグ付けされていた。
- **CFの3区分と現金同等物は全形式で取得可能**（タグ名は基準別に異なるのみ。下表）。

### 形式1: jgaap_general（日本基準・一般）

現行アプリが対応している形式。`jppfs_cor` 名前空間。BS=流動資産/固定資産（有形・無形・投資その他の3分類）/流動負債/固定負債/純資産、PL=売上高→営業利益→経常利益→特別損益→当期純利益。売上高・売上原価は業種による科目ゆれあり（完成工事高など。現行実装のフォールバックリストを踏襲）。

### 形式2: jgaap_bank（日本基準・銀行）— 三菱UFJ FGで実測

- BS: **流動/固定の区分が存在しない**。資産・負債は業種固有の内訳科目
  （`〜AssetsBNK` / `〜LiabilitiesBNK` サフィックス）。ただし**合計は汎用タグで取れる**: `jppfs_cor:Assets`（431.7兆）/ `jppfs_cor:Liabilities`（408.0兆）/ `jppfs_cor:NetAssets`（23.7兆）。主要内訳（実測、いずれも `CurrentYearInstant`）:
  - `jppfs_cor:LoansAndBillsDiscountedAssetsBNK` 貸出金 133.8兆
  - `jppfs_cor:SecuritiesAssetsBNK` 有価証券 85.7兆
  - `jppfs_cor:CashAndDueFromBanksAssetsBNK` 現金預け金 90.0兆
  - `jppfs_cor:DepositsLiabilitiesBNK` 預金 239.4兆
- PL: 売上高・営業利益は存在せず**経常収益/経常費用**型:
  - `jppfs_cor:OrdinaryIncomeBNK` 経常収益 14.62兆（※BNKサフィックス付き）
  - `jppfs_cor:OrdinaryExpensesBNK` 経常費用 11.21兆
  - `jppfs_cor:OrdinaryIncome` 経常利益 3.41兆（※**汎用タグと同名**。BNKなしが経常利益）
  - 特別損益・`IncomeBeforeIncomeTaxes`・`ProfitLoss`・`ProfitLossAttributableToOwnersOfParent` は一般形式と同じ汎用タグ
- CF: **汎用タグがそのまま使われる**: `NetCashProvidedByUsedInOperatingActivities`（-23.1兆。銀行は営業CFが巨額になる）
  / `...InvestmentActivities` / `...InFinancingActivities` / `CashAndCashEquivalents`（期首=Prior1YearInstant）。

### 形式3: ifrs_classified（IFRS・流動/非流動分類）— 武田・三菱商事・NTTで実測

`jpigp_cor` 名前空間（IFRSタクソノミの様式511000）。

- BS: `CurrentAssetsIFRS` / `NonCurrentAssetsIFRS` / `AssetsIFRS` /
  `TotalCurrentLiabilitiesIFRS`（※Totalプレフィクス付き）/`NonCurrentLabilitiesIFRS`（※**タクソノミ公式のタイポ**。1g_IFRS_ElementList.xlsxでも確認）/`LiabilitiesIFRS` / `EquityAttributableToOwnersOfParentIFRS` / `NonControllingInterestsIFRS` / `EquityIFRS`。のれん・無形は企業差: 武田=`GoodwillIFRS`+`IntangibleAssetsIFRS` 別掲、三菱商事=`GoodwillAndIntangibleAssetsIFRS` 合算。
- PL: 骨格（税引前利益から下）は共通、中間は企業差が大きい:
  - 武田: `RevenueIFRS` → `CostOfSalesIFRS`/`SellingGeneralAndAdministrativeExpensesIFRS` →
    `OperatingProfitLossIFRS` あり。**売上総利益タグなし**
  - 三菱商事: `Revenue2IFRS`（収益）→ `GrossProfitIFRS` あり。**営業利益タグなし**
  - NTT: 収益が**企業拡張タグ** `jpcrp030000-asr_E04430-000:OperatingRevenuesIFRS`（営業収益14.41兆）。
    標準の `jpigp_cor` に収益factなし。費用は `OperatingExpensesIFRS`（営業費用一括12.70兆）、
    `OperatingProfitLossIFRS` あり
  - 全社共通: `ProfitLossBeforeTaxIFRS` / `IncomeTaxExpenseIFRS` / `ProfitLossIFRS` /
    `ProfitLossAttributableToOwnersOfParentIFRS` / `FinanceIncomeIFRS` / `FinanceCostsIFRS`
- 収益の確実なフォールバック: `jpcrp_cor:RevenueIFRSSummaryOfBusinessResults`（経営指標サマリ）が
  武田・三菱商事・NTT・楽天の4社に存在し、本表の値と完全一致（NTTの拡張タグ問題もこれで回収できる）。

### 形式4: ifrs_liquidity（IFRS・流動性配列）— 楽天・東京海上で実測

`jpigp_cor`（様式512000）。**`CurrentAssetsIFRS` 等の流動/非流動タグが1件も存在しない**（楽天のfactダンプで `CurrentAssetsIFRS` 出現0件を確認。512000様式ツリー自体に流動/非流動の要素がない）。

- BS: 資産・負債がフラットな科目列 + 合計のみ:
  `AssetsIFRS` / `LiabilitiesIFRS` / `EquityIFRS` / `EquityAttributableToOwnersOfParentIFRS` /`NonControllingInterestsIFRS` / `CashAndCashEquivalentsIFRS`。内訳は `〜AssetsIFRS` / `〜LiabilitiesIFRS` サフィックスの科目（例: 楽天 `TradeReceivables2AssetsIFRS`、`BondsAndBorrowingsLiabilitiesIFRS`）で企業ごとに構成が異なる。
- PL:
  - 楽天: `RevenueIFRS`（2.50兆）→ `OperatingExpensesIFRS`（営業費用一括2.40兆）→
    `OperatingProfitLossIFRS`。原価/販管費の分解なし
  - 東京海上（保険IFRS17）: 保険収益が**企業拡張タグ** `jpcrp030000-asr_E03847-000:InsuranceRevenueIFRS`（7.69兆）。
    標準タグの収益なし。**`jpcrp_cor:RevenueIFRSSummaryOfBusinessResults` も存在しない**
    → 標準タグだけではPLのトップラインが取得不可能な実例。
    `ProfitLossBeforeTaxIFRS`（0.75兆）以下のボトムは取得可能
- CF: 3区分とも `jpigp_cor` の共通タグで両社とも取得可能。

## 1g_IFRS_ElementList.xlsx（金融庁 IFRSタクソノミ要素リスト）からの知見

詳細ツリーシート（962行）の構成:

- **511000 財政状態計算書（流動／非流動）** と **512000 財政状態計算書（流動性配列）** の
  2様式が公式に存在する。512000には流動/非流動の合計要素自体がない
- **521000 損益計算書**: 収益の標準要素は `RevenueIFRS`（売上収益）/ `NetSalesIFRS`（売上高）/
  `Revenue2IFRS`（収益）の3系列。`GrossProfitIFRS`・`OperatingProfitLossIFRS` は任意項目。`OperatingExpensesIFRS`（営業費用）あり。経常利益・特別損益に相当する要素は存在しない
- **540000 CF計算書**: `NetCashProvidedByUsedInOperatingActivitiesIFRS` 等の3区分 +
  `NetIncreaseDecreaseInCashAndCashEquivalentsIFRS` + `CashAndCashEquivalentsIFRS`
- 要素メタデータとして periodType（instant/duration）と balance（debit/credit）が定義されており、
  マッピング作成時の科目性質の確認に使える

## 設計への示唆（まとめ）

1. 形式判定は「会計基準 + 業種DEI + 特定タグの実在チェック」の3段で行う
   （IFRSのclassified/liquidityはタグ実在でしか判定できない）
2. 収益はフォールバックリスト必須。最後の砦は `jpcrp_cor` 経営指標サマリ。
   それでも取れない企業（保険IFRS）が実在するため「PLは表示不可」を正常系として扱う設計が必要
3. 合計科目（資産・負債・資本、税引前利益・当期利益、CF3区分）は全形式で取れるので
   共通の科目コードに正規化できる。中間科目が形式別の個別化ポイント
4. 銀行の経常利益のように「同じタグ名が形式によって別の意味の並びに現れる」ため、
   マッピングは形式ごとに独立定義すべき（グローバルな1枚のマッピング表にしない）

## 検証用データ（実測値。テストの期待値に使用）

| item | 武田 S100YB5L | 三菱商事 S100YB25 | NTT S100YCP3 | 楽天 S100XTNW | 東京海上 S100YLS8 | MUFG S100YJQO |
|---|---|---|---|---|---|---|
| bs.assets | 15,511,506 | 24,151,695 | 46,721,259 | 28,804,400 | 33,002,651 | 431,731,548 |
| bs.equity | 7,430,649 | 10,250,574 | 10,217,533 | 1,354,232 | 8,052,371※1 | 23,744,152 |
| pl.revenue | 4,505,720 | 18,915,995 | 14,409,121※2 | 2,496,575 | 取得不可 | −（銀行は経常収益14,620,843） |
| pl.profit_before_tax | -142,355 | 1,096,094 | 1,581,923 | -29,550 | 750,700 | 3,322,161 |
| cf.operating | 1,041,431 | 1,490,041 | 1,485,190 | 424,093 | 1,390,562 | -23,064,420 |

単位: 百万円。※1 = 親会社帰属7,955,554 + 非支配96,816。※2 = サマリタグからのフォールバック値。
