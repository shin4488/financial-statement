# XBRLタグ ↔ 科目コード ↔ Builder 対応表

「このタグはどの科目コードになり、どのグラフで使われるか」を引くための表。XBRLタグを扱う作業のときに開く。

- タグの実測値・企業ごとの差異は [06_xbrl_research.md](06_xbrl_research.md)
- なぜこの3段構えなのかは [00_layering.md](00_layering.md)

---

## 読み方

データは3回姿を変える。この表は左から右へ辿れるように並べてある。

```
XBRLタグ          →   科目コード      →   Builder        →  グラフの段
jpigp_cor:AssetsIFRS  bs.assets          BsIfrsClassified   借方バー
jppfs_cor:Assets      bs.assets          BsJgaapBank        借方バー
（形式ごとに別）        （全形式で共通）      （形式ごとに別）
```

表中の略記:

| 略記 | 形式 | 対象 |
|---|---|---|
| 一般 | `jgaap_general` | 日本基準・一般事業会社 |
| 銀行 | `jgaap_bank` | 日本基準・銀行 |
| 分類 | `ifrs_classified` | IFRS・流動/非流動分類BS（様式511000） |
| 配列 | `ifrs_liquidity` | IFRS・流動性配列BS（様式512000） |

名前空間: `jppfs_cor` = 日本基準、`jpigp_cor` = IFRS、`jpcrp_cor` = 有報の共通部分（表紙・経営指標）。

コンテキスト（どの時点・期間の値か）は科目の性質で決まる。

| 種別 | コンテキストID | 対象 |
|---|---|---|
| 時点 | `CurrentYearInstant` | BSの残高 |
| 期間 | `CurrentYearDuration` | PL・CFの増減 |
| 前期末時点 | `Prior1YearInstant` | CFの期首残高のみ |

単体財務諸表は上記に `_NonConsolidatedMember` が付く。IFRS適用企業でも単体は日本基準（`jppfs_cor`）でタグ付けされるため、単体は常に「一般」または「銀行」の形式で処理される。

---

## BS（貸借対照表）

### 全形式で共通して取る科目

合計3科目はどの形式でも取得できる。ここが正規化の土台になる。

| 科目コード | 日本語 | 一般 / 銀行 | 分類 / 配列 | 使うBuilder |
|---|---|---|---|---|
| `bs.assets` | 資産合計 | `jppfs_cor:Assets` | `jpigp_cor:AssetsIFRS` | 銀行・分類・配列 |
| `bs.liabilities` | 負債合計 | `jppfs_cor:Liabilities` | `jpigp_cor:LiabilitiesIFRS` | 銀行・配列 |
| `bs.equity` | 資本（純資産）合計 | `jppfs_cor:NetAssets` | `jpigp_cor:EquityIFRS` | BS全Builder |
| `bs.cash_and_equivalents` | 現金及び現金同等物 | 一般 `jppfs_cor:CashAndCashEquivalents`<br>銀行 `jppfs_cor:CashAndDueFromBanksAssetsBNK` | `jpigp_cor:CashAndCashEquivalentsIFRS` | 銀行・配列 |

銀行の `bs.cash_and_equivalents` だけタグが違うのは、BSの「現金預け金」とCFの「現金及び現金同等物」が銀行では別概念のため。値が一致する銀行もあるが混同しないこと。

### 流動 / 非流動の区分（一般・分類のみ）

銀行と配列にはこの区分が存在しない。

| 科目コード | 日本語 | 一般 | 分類 | 使うBuilder |
|---|---|---|---|---|
| `bs.current_assets` | 流動資産 | `jppfs_cor:CurrentAssets` | `jpigp_cor:CurrentAssetsIFRS` | 一般・分類 |
| `bs.non_current_assets` | 非流動（固定）資産 | `jppfs_cor:NoncurrentAssets` | `jpigp_cor:NonCurrentAssetsIFRS` | 分類 |
| `bs.current_liabilities` | 流動負債 | `jppfs_cor:CurrentLiabilities` | `TotalCurrentLiabilitiesIFRS`<br>→ `CurrentLiabilitiesIFRS` | 一般・分類 |
| `bs.non_current_liabilities` | 非流動（固定）負債 | `jppfs_cor:NoncurrentLiabilities` | `NonCurrentLabilitiesIFRS`<br>→ `NonCurrentLiabilitiesIFRS` | 一般・分類 |

`NonCurrentLabilities` は綴りが誤っているように見えるが、金融庁のタクソノミ側のタイポがそのまま公式要素名になっている（`1g_IFRS_ElementList.xlsx` で確認済み）。将来修正される可能性があるので、正しい綴りもフォールバックに入れてある。

### 形式固有の内訳科目

| 科目コード | 日本語 | 形式 | XBRLタグ | 使うBuilder |
|---|---|---|---|---|
| `bs.tangible_fixed_assets` | 有形固定資産 | 一般 | `jppfs_cor:PropertyPlantAndEquipment` | 一般 |
| `bs.intangible_fixed_assets` | 無形固定資産 | 一般 | `jppfs_cor:IntangibleAssets` | 一般 |
| `bs.investments_and_other_assets` | 投資その他の資産 | 一般 | `jppfs_cor:InvestmentsAndOtherAssets` | 一般 |
| `bs.loans` | 貸出金 | 銀行 | `jppfs_cor:LoansAndBillsDiscountedAssetsBNK` | 銀行 |
| `bs.securities` | 有価証券 | 銀行 | `jppfs_cor:SecuritiesAssetsBNK` | 銀行 |
| `bs.deposits` | 預金 | 銀行 | `jppfs_cor:DepositsLiabilitiesBNK` | 銀行 |
| `bs.property_plant_and_equipment` | 有形固定資産 | 分類 | `jpigp_cor:PropertyPlantAndEquipmentIFRS` | — |
| `bs.goodwill_and_intangibles` | のれん及び無形資産 | 分類 | 下記の合算処理 | — |
| `bs.equity_attributable_to_owners` | 親会社所有者帰属持分 | 分類・配列 | `jpigp_cor:EquityAttributableToOwnersOfParentIFRS` | — |
| `bs.non_controlling_interests` | 非支配持分 | 分類・配列 | `jpigp_cor:NonControllingInterestsIFRS` | — |

Builderが「—」の科目も保存している。再取込のコストが高いので骨格は広めに取っておき、将来の指標計算やコメント生成の入力に使えるようにしてある。

---

## PL（損益計算書）

### 全形式で共通

| 科目コード | 日本語 | 一般・銀行 | 分類・配列 | 使うBuilder |
|---|---|---|---|---|
| `pl.profit_before_tax` | 税引前利益 | `jppfs_cor:IncomeBeforeIncomeTaxes` | `jpigp_cor:ProfitLossBeforeTaxIFRS` | IFRS |
| `pl.income_tax` | 法人税等 | `jppfs_cor:IncomeTaxes` | `jpigp_cor:IncomeTaxExpenseIFRS` | — |
| `pl.profit` | 当期純利益 | `jppfs_cor:ProfitLoss` | `jpigp_cor:ProfitLossIFRS` | — |
| `pl.profit_attributable_to_owners` | 親会社帰属当期純利益 | `jppfs_cor:ProfitLossAttributableToOwnersOfParent` | `jpigp_cor:ProfitLossAttributableToOwnersOfParentIFRS` | — |

### トップライン（売上・収益）

企業によって科目名が揺れるため、フォールバックリストで順に引く（先に取れた方を採用）。

**一般** — `pl.revenue`

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:OperatingRevenue1` | 営業収益 |
| 2 | `jppfs_cor:NetSales` | 売上高 |
| 3 | `jppfs_cor:ContractsCompletedRevOA` | 完成工事高 |
| 4 | `jppfs_cor:NetSalesOfCompletedConstructionContractsCNS` | 完成工事高（建設業） |

営業収益を売上高より先に置いている。営業収益型（売上高と営業収入をまとめて開示する小売業など）は両方のタグを持つが、営業利益と貸借が合うのは営業収益の側になるため。

**分類・配列** — `pl.revenue`

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jpigp_cor:RevenueIFRS` | 売上収益 |
| 2 | `jpigp_cor:Revenue2IFRS` | 収益 |
| 3 | `jpigp_cor:NetSalesIFRS` | 売上高 |
| 4 | `jpcrp_cor:RevenueIFRSSummaryOfBusinessResults` | 経営指標サマリ（本表ではない） |

最後の1つだけ本表ではなく経営指標サマリから取っている。本表の収益が企業拡張タグしか無い企業（NTTなど）を救うための最後の手段で、値は本表と一致することを実測で確認済み。順番を最後にしているのは、本表のタグの方が一次情報だから。

**銀行** — 売上高という概念が無いため `pl.revenue` は保存しない。

| 科目コード | XBRLタグ | 日本語 | MUFG実測 |
|---|---|---|---|
| `pl.ordinary_revenue` | `jppfs_cor:OrdinaryIncomeBNK` | 経常収益 | 14.6兆 |
| `pl.ordinary_expenses` | `jppfs_cor:OrdinaryExpensesBNK` | 経常費用 | 11.2兆 |
| `pl.ordinary_profit` | `jppfs_cor:OrdinaryIncome` | 経常利益 | 3.4兆 |

`OrdinaryIncomeBNK` が経常収益、サフィックスなしの `OrdinaryIncome` が経常利益で、名前が似ているのに意味が違う。取り違えると桁が大きく狂う。

### 費用・利益の中間段階

| 科目コード | 日本語 | 一般 | 分類・配列 | 使うBuilder |
|---|---|---|---|---|
| `pl.cost_of_sales` | 売上原価 | フォールバック8件（下記） | `jpigp_cor:CostOfSalesIFRS` | 一般・IFRS |
| `pl.sga` | 販売費及び一般管理費 | `jppfs_cor:SellingGeneralAndAdministrativeExpenses` | `jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS` | 一般・IFRS |
| `pl.operating_expenses` | 営業費用（一括計上） | — | `jpigp_cor:OperatingExpensesIFRS` | IFRS |
| `pl.gross_profit` | 売上総利益 | `jppfs_cor:GrossProfit` | `jpigp_cor:GrossProfitIFRS` | — |
| `pl.operating_profit` | 営業利益 | `jppfs_cor:OperatingIncome` | `jpigp_cor:OperatingProfitLossIFRS` | 一般 |
| `pl.ordinary_profit` | 経常利益 | `jppfs_cor:OrdinaryIncome` | 存在しない | 銀行 |
| `pl.non_operating_income` | 営業外収益 | `jppfs_cor:NonOperatingIncome` | 存在しない | — |
| `pl.non_operating_expenses` | 営業外費用 | `jppfs_cor:NonOperatingExpenses` | 存在しない | — |
| `pl.extraordinary_income` | 特別利益 | `jppfs_cor:ExtraordinaryIncome` | 存在しない | — |
| `pl.extraordinary_loss` | 特別損失 | `jppfs_cor:ExtraordinaryLoss` | 存在しない | — |

一般の `pl.cost_of_sales` のフォールバック（順序が優先度）:

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:OperatingCost` | 営業原価 |
| 2 | `jppfs_cor:CostOfSales` | 売上原価 |
| 3 | `jppfs_cor:CostOfMerchandiseAndFinishedGoodsSoldCOS` | 商品及び製品売上原価 |
| 4 | `jppfs_cor:CostOfFinishedGoodsSold` | 製品売上原価 |
| 5 | `jppfs_cor:CostOfGoodsSold` | 商品売上原価 |
| 6 | `jppfs_cor:CostOfCompletedWorkCOSExpOA` | 完成工事原価 |
| 7 | `jppfs_cor:CostOfSalesOfCompletedConstructionContractsCNS` | 完成工事原価（建設業） |
| 8 | `jppfs_cor:CostOfProductsManufactured` | 当期製品製造原価 |

営業原価が先頭なのは、営業収益とペアの原価だから（営業収益型の企業は売上原価も併記するが、そちらは売上高側の原価になる）。当期製品製造原価が最後なのは、売上原価の代わりにこれで本表を開示する製造業がある一方、通常は製造原価明細の項目として売上原価と併記されるため。

IFRSの営業利益（`pl.operating_profit`）は保存はするがBuilderでは使っていない。IFRSでは開示が任意で、開示する企業としない企業が混在して企業間の比較にならないため。

---

## CF（キャッシュ・フロー計算書）

| 科目コード | 日本語 | 一般・銀行 | 分類・配列 |
|---|---|---|---|
| `cf.operating` | 営業活動によるCF | `jppfs_cor:NetCashProvidedByUsedInOperatingActivities` | `jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS` |
| `cf.investing` | 投資活動によるCF | `jppfs_cor:NetCashProvidedByUsedInInvestmentActivities` | `jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS` |
| `cf.financing` | 財務活動によるCF | `jppfs_cor:NetCashProvidedByUsedInFinancingActivities` | `jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS` |
| `cf.cash_end` | 現金及び現金同等物の期末残高 | `jppfs_cor:CashAndCashEquivalents` | `jpigp_cor:CashAndCashEquivalentsIFRS` |
| `cf.cash_begin` | 同・期首残高 | 同上（`Prior1YearInstant`） | 同上（`Prior1YearInstant`） |

投資活動のタグ名が日本基準は `Investment`、IFRSは `Investing` で異なる。CFは5科目そろわないとウォーターフォールが繋がらないため、1つでも欠けるとチャートは `renderable: false` になる。

期首残高だけはマッピング表に載せられない。表は `CurrentYear` のコンテキストを前提としており、期首残高は前期末（`Prior1YearInstant`）を見る必要があるため、各Extractorの`extract_extras` フックで個別に実装している。

---

## マッピング表で表せないもの

タグと科目コードが1対1、あるいは1対Nのフォールバックで済まないケースは`extract_extras` に書く。現在あるのは2種類だけ。

| ケース | 実装している形式 | 内容 |
|---|---|---|
| 別コンテキストの参照 | 全形式 | CF期首残高（`Prior1YearInstant`） |
| 複数タグの合算 | 分類 | のれん + 無形資産 |

のれんの合算は、合算タグを開示する企業（三菱商事）と別掲する企業（武田）があるため、合算タグを先に探し、無ければ2タグを足して1つの科目コードに正規化している。

```ruby
combined = money("jpigp_cor:GoodwillAndIntangibleAssetsIFRS", ...)
if combined.nil?
  combined = [money("jpigp_cor:GoodwillIFRS", ...),
              money("jpigp_cor:IntangibleAssetsIFRS", ...)].compact.sum
end
```

---

## 標準タグで取れない場合の扱い

企業が独自に定義した拡張タグ（`jpcrp030000-asr_E04430-000:...` のような名前空間）は意図的に読んでいない。企業ごとに意味の保証がないため、`Xbrl::Document` の時点で標準タクソノミ以外を弾いている。

そのため、収益が拡張タグにしか無い企業では `pl.revenue` が取得できない。

| 企業 | 状況 | 結果 |
|---|---|---|
| NTT | 本表は拡張タグだが経営指標サマリに標準タグあり | サマリから取得して表示できる |
| 東京海上HD | 拡張タグのみ。サマリにも無い | PLだけ `renderable: false`。BS・CFは表示 |

取れないことをエラーではなく正常系として扱い、チャート単位で表示を落とす設計にしてある（カード全体は消さない）。詳細は [03_serving.md](03_serving.md)。

---

## 新しいタグを追加するとき

1. 対象企業の有報XBRLを取得して実際のタグを確認する（[06](06_xbrl_research.md) の手順）
2. 科目コードが未定義なら `item_codes.rb` に追加する
3. 該当形式のExtractorのマッピング定数に1行足す
4. 表示に使うなら該当BuilderのSPECに追加する
5. この文書の表を更新する

3で `item_codes.rb` に無いコードを書くと、`mapping_consistency_spec.rb` が落ちて気づけるようになっている。
