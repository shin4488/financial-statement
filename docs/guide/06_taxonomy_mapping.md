# 06. XBRLタグ対応表と実地調査

【資料】前半は「このタグはどの科目コードになり、どのグラフで使われるか」を引く対応表、後半（「実地調査の記録」以降）はその根拠になった実測記録。XBRLタグを扱う作業のときは、**前半の触る表（BS / PL / CF）の節だけ**開けばよい。

- 記法（フォールバック・`sum`・`max`）の意味と設計の「なぜ」、タグを追加する手順（変更ガイド）は[03章](03_data_flow.md)
- 後半の実測記録（調査対象の企業・docID・検証用の実測値）は、対応の理由を確かめたいときだけ開けばよい。タグ対応を変えるときは表とセットで更新する

| 節 | 内容 |
|---|---|
| [凡例](#凡例) | 形式の略記と業種接尾辞の一覧 |
| [BS（貸借対照表）](#bs貸借対照表) | 共通4科目・流動/非流動の区分・形式固有の内訳 |
| [PL（損益計算書）](#pl損益計算書) | 共通科目・トップライン・費用と利益のフォールバック |
| [CF（キャッシュ・フロー計算書）](#cfキャッシュフロー計算書) | CF5科目とサマリ（ifrs_summary）のタグ |
| [複数タグの合算の対象](#複数タグの合算の対象) | `sum(...)` で合算している科目の一覧 |
| [実地調査の記録](#実地調査の記録) | 根拠の実測: 調査対象8社・発見と実装への反映・検証用の実測値・業種別の実測・3年分の全数検証 |

## 凡例

| 略記 | 形式 | 対象 |
|---|---|---|
| 一般 | `jgaap_general` | 日本基準・一般事業会社（建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・商品先物・投資業など、業種別の勘定科目を持つが骨格が同じ業種を含む） |
| 銀行 | `jgaap_bank` | 日本基準・銀行 |
| 保険 | `jgaap_insurance` | 日本基準・保険（生保・損保） |
| 分類 | `ifrs_classified` | IFRS・流動/非流動分類BS（様式511000） |
| 配列 | `ifrs_liquidity` | IFRS・流動性配列BS（様式512000） |
| サマリ | `ifrs_summary` | IFRS・詳細タグなし（2019年3月期より前の有報。経営指標サマリ `jpcrp_cor:*IFRSSummaryOfBusinessResults` のみで構成） |

「使うBuilder」列が「—」の科目はチャートでは未使用（保存のみ。広めに保存する方針は[03章](03_data_flow.md)）。

業種別の勘定科目のタグは、標準タグ名に業種の接尾辞が付く（`OperatingRevenueELE`=電気の営業収益、`OperatingExpensesRWY`=鉄道の営業費）。接尾辞は業種DEIコードと同じ（一覧はEDINETタクソノミの勘定科目リスト `1f_AccountList.xlsx` の業種別シート）。

| 接尾辞 | 業種 | 接尾辞 | 業種 | 接尾辞 | 業種 |
|---|---|---|---|---|---|
| CNS | 建設 | BNK | 銀行 | INS | 保険 |
| SEC | 証券 | RWY | 鉄道 | WAT | 海運 |
| ELC | 電気通信 | ELE | 電気 | GAS | ガス |
| SPF | 特定金融 | CMD | 商品先物 | IVT / INV | 投資運用 / 投資業 |

長いタグ名は、表の列幅が偏らないよう途中に半角空白を入れて表記している。実際のタグ名に空白は無い。

## BS（貸借対照表）

### 全形式で共通して取る科目

この4科目は本表の詳細タグがある形式（サマリ以外）ならどれでも取得できる。形式をまたぐ検索・表示はこの4科目を前提にできる（サマリはBS科目を保存しない。後述「サマリのタグ」）。

| 科目コード | 日本語 | 一般 / 銀行 | 分類 / 配列 | 使うBuilder |
|---|---|---|---|---|
| `bs.assets` | 資産合計 | `jppfs_cor:Assets` | `jpigp_cor:AssetsIFRS` | 銀行・保険・分類・配列 |
| `bs.liabilities` | 負債合計 | `jppfs_cor:Liabilities` | `jpigp_cor:LiabilitiesIFRS` | 銀行・保険・配列 |
| `bs.equity` | 資本（純資産）合計 | `jppfs_cor:NetAssets` | `jpigp_cor:EquityIFRS` | BS全Builder |
| `bs.cash_and_equivalents` | 現金及び現金同等物 | 一般 `jppfs_cor:CashAndCashEquivalents`<br>銀行 `jppfs_cor:CashAndDueFromBanksAssetsBNK`<br>保険 `jppfs_cor:CashAndDepositsAssetsINS` | `jpigp_cor:CashAndCashEquivalentsIFRS` | 銀行・保険・配列 |

銀行・保険の `bs.cash_and_equivalents` だけタグが違うのは、BSの「現金預け金」「現金及び預貯金」とCFの「現金及び現金同等物」が金融機関では別概念のため。値が一致する銀行もあるが混同しないこと。

### 流動 / 非流動の区分（一般・分類のみ）

銀行・保険と配列にはこの区分が存在しない。

| 科目コード | 日本語 | 一般 | 分類 | 使うBuilder |
|---|---|---|---|---|
| `bs.current_assets` | 流動資産 | `jppfs_cor:CurrentAssets` | `jpigp_cor:CurrentAssetsIFRS` | 一般・分類 |
| `bs.non_current_assets` | 非流動（固定）資産 | `jppfs_cor:NoncurrentAssets` | `jpigp_cor:NonCurrentAssetsIFRS` | 分類 |
| `bs.current_liabilities` | 流動負債 | `jppfs_cor:CurrentLiabilities` | `TotalCurrentLiabilitiesIFRS`<br>→ `CurrentLiabilitiesIFRS` | 一般・分類 |
| `bs.non_current_liabilities` | 非流動（固定）負債 | `jppfs_cor:NoncurrentLiabilities` | `NonCurrentLabilitiesIFRS`<br>→ `NonCurrentLiabilitiesIFRS` | 一般・分類 |

`NonCurrentLabilities` は綴りが誤っているように見えるが、金融庁のタクソノミ側のタイポがそのまま公式要素名になっている（後述「実地調査の記録」で確認済み）。将来修正される可能性があるので、正しい綴りもフォールバックに入れてある。

一般の固定資産は「有形固定資産・無形固定資産・投資その他の資産」の3分類（次表）で描くが、電気・鉄道・電気通信の単体など業種別様式では固定資産を事業用資産（電気事業固定資産・鉄道事業固定資産など）で区分し、有形/無形の標準タグを持たない（投資その他の資産だけ標準タグで取れる）。BuilderはこのときBSを `bs.non_current_assets`（固定資産合計）の1段で描く（[03章](03_data_flow.md)）。

### 形式固有の内訳科目

| 科目コード | 日本語 | 形式 | XBRLタグ | 使うBuilder |
|---|---|---|---|---|
| `bs.tangible_fixed_assets` | 有形固定資産 | 一般 | `jppfs_cor:PropertyPlantAndEquipment` | 一般 |
| `bs.intangible_fixed_assets` | 無形固定資産 | 一般 | `jppfs_cor:IntangibleAssets` | 一般 |
| `bs.investments_and_other_assets` | 投資その他の資産 | 一般 | `jppfs_cor:InvestmentsAndOtherAssets` | 一般 |
| `bs.loans` | 貸出金 / 貸付金 | 銀行・保険 | 銀行 `jppfs_cor:LoansAndBills` `DiscountedAssetsBNK`<br>保険 `jppfs_cor:LoansReceivablesAssetsINS` | 銀行・保険 |
| `bs.securities` | 有価証券 | 銀行・保険 | 銀行 `jppfs_cor:SecuritiesAssetsBNK`<br>保険 `jppfs_cor:SecuritiesAssetsINS` | 銀行・保険 |
| `bs.deposits` | 預金 | 銀行 | `jppfs_cor:DepositsLiabilitiesBNK` | 銀行 |
| `bs.policy_reserves` | 保険契約準備金 | 保険 | `jppfs_cor:ReserveForInsurance` `PolicyLiabilitiesLiabilitiesINS` | 保険 |
| `bs.property_plant_and_equipment` | 有形固定資産 | 分類 | `jpigp_cor:PropertyPlantAndEquipmentIFRS` | — |
| `bs.goodwill_and_intangibles` | のれん及び無形資産 | 分類 | 下記の合算処理 | — |
| `bs.equity_attributable_to_owners` | 親会社所有者帰属持分 | 分類・配列 | `jpigp_cor:EquityAttributableTo` `OwnersOfParentIFRS` | — |
| `bs.non_controlling_interests` | 非支配持分 | 分類・配列 | `jpigp_cor:NonControllingInterestsIFRS` | — |

## PL（損益計算書）

### 全形式で共通

| 科目コード | 日本語 | 一般・銀行・保険 | 分類・配列 | 使うBuilder |
|---|---|---|---|---|
| `pl.profit_before_tax` | 税引前利益 | `jppfs_cor:IncomeBeforeIncomeTaxes` | `jpigp_cor:ProfitLossBeforeTaxIFRS` | IFRS |
| `pl.income_tax` | 法人税等 | `jppfs_cor:IncomeTaxes` | `jpigp_cor:IncomeTaxExpenseIFRS` | — |
| `pl.profit` | 当期純利益 | `jppfs_cor:ProfitLoss` | `jpigp_cor:ProfitLossIFRS` | — |
| `pl.profit_attributable_to_owners` | 親会社帰属当期純利益 | `jppfs_cor:ProfitLoss` `AttributableToOwnersOfParent` | `jpigp_cor:ProfitLoss` `AttributableToOwnersOfParentIFRS` | — |

### トップライン（売上・収益）

企業によって科目名が揺れるため、フォールバックリストで順に引く（先に取れた方を採用）。

**一般** — `pl.revenue`

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:OperatingRevenueRWY` / `OperatingRevenueTotalRWY` | 営業収益 / 全事業営業収益（鉄道） |
| 2 | `jppfs_cor:OperatingRevenueELE` | 営業収益（電気） |
| 3 | `jppfs_cor:OperatingRevenueSEC` | 営業収益（証券） |
| 4 | `jppfs_cor:OperatingRevenueSPF` | 営業収益（特定金融） |
| 5 | `jppfs_cor:OperatingRevenueCMD` | 営業収益（商品先物） |
| 6 | `jppfs_cor:OperatingRevenueIVT` / `OperatingRevenueINV` | 営業収益（投資運用 / 投資業） |
| 7 | `jppfs_cor:ShippingBusinessRevenue` `AndOtherOperatingRevenueWAT` | 海運業収益及びその他の営業収益（海運） |
| 8 | 最大値 `max(OperatingRevenue1, NetSales + OperatingRevenue2)` | 一般事業会社の総額: 営業収益 と 売上高+営業収入 の大きい方（企業のタグ付けの揺れを吸収する。なぜ最大値かは[03章](03_data_flow.md)） |
| 9 | `jppfs_cor:SalesFromGasBusinessGAS` → `GasSalesGAS` | ガス事業売上高 → ガス売上（ガス。単体は売上高でなくこれらで開示する） |
| 10 | `jppfs_cor:ContractsCompletedRevOA` | 完成工事高 |
| 11 | `jppfs_cor:NetSalesOfCompleted` `ConstructionContractsCNS` | 完成工事高（建設業） |
| 12 | 合算 `OperatingRevenue{Railway, Railroad, Related, Incidental, SideLine, RealEstate, Development, Automobile, Other}RWY` | 鉄道（単体）: 事業区分別の営業収益の合計 |
| 13 | 合算 `OperatingRevenueOILTelecommunications` + `OperatingRevenueIncidentalELC` | 電気通信: 電気通信事業営業収益 + 附帯事業営業収益 |
| 14 | 合算 `ShippingBusinessRevenueWAT` + `OtherBusinessRevenueWAT` | 海運（単体）: 海運業収益 + その他事業収益 |

業種固有の営業収益（1〜7）を一般の総額（8）より先に置くのは、商品先物取引業のように商品売上高（`NetSales`）が営業収益の内訳になる業種があるため（業種の接尾辞が付くタグはその業種の有報にしか現れないので、業種をまたぐ順序に意味はなく、同一業種内の「合計タグ → 区分の合算」の順序だけが効く）。

**分類・配列** — `pl.revenue`

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jpigp_cor:RevenueIFRS` | 売上収益 |
| 2 | `jpigp_cor:Revenue2IFRS` | 収益 |
| 3 | `jpigp_cor:NetSalesIFRS` | 売上高 |
| 4 | `jpcrp_cor:RevenueIFRS` `SummaryOfBusinessResults` | 経営指標サマリ（本表ではない） |

最後の1つだけ本表ではなく経営指標サマリから取っている。本表の収益が企業拡張タグしか無い企業（NTTなど。拡張タグを読まない方針は[03章](03_data_flow.md)）でも取得できるようにする最終フォールバックで、値は本表と一致することを実測で確認済み（後述「実地調査の記録」）。順番を最後にしているのは、本表のタグの方が一次情報だから。

**銀行・保険** — 売上高という概念が無いため `pl.revenue` は保存しない。

| 科目コード | 銀行 | 保険 | 日本語 |
|---|---|---|---|
| `pl.ordinary_revenue` | `jppfs_cor:OrdinaryIncomeBNK` | `jppfs_cor:OperatingIncomeINS` | 経常収益 |
| `pl.ordinary_expenses` | `jppfs_cor:OrdinaryExpensesBNK` | `jppfs_cor:OperatingExpensesINS` | 経常費用 |
| `pl.ordinary_profit` | `jppfs_cor:OrdinaryIncome` | `jppfs_cor:OrdinaryIncome` | 経常利益 |

`OrdinaryIncomeBNK` が経常収益、サフィックスなしの `OrdinaryIncome` が経常利益で、名前が似ているのに意味が違う。保険はさらに紛らわしく、経常収益のタグ名が `OperatingIncomeINS`（一般形式の営業利益 `OperatingIncome` と同系の名前）。取り違えると桁が大きく狂う。

### 費用・利益の中間段階

| 科目コード | 日本語 | 一般 | 分類・配列 | 使うBuilder |
|---|---|---|---|---|
| `pl.cost_of_sales` | 売上原価 | フォールバック11件（下記） | `jpigp_cor:CostOfSalesIFRS` | 一般・IFRS |
| `pl.financial_expenses` | 金融費用 | `jppfs_cor:FinancialExpensesSEC`（証券。営業収益−金融費用=純営業収益） | 存在しない | 一般 |
| `pl.sga` | 販売費及び一般管理費 | フォールバック4件（下記） | `jpigp_cor:SellingGeneralAnd` `AdministrativeExpensesIFRS` | 一般・IFRS |
| `pl.operating_expenses` | 営業費用（一括計上） | フォールバック10件（下記） | `jpigp_cor:OperatingExpensesIFRS` | 一般・IFRS |
| `pl.gross_profit` | 売上総利益 | `jppfs_cor:GrossProfit` → `OperatingGrossProfit`（営業総利益）→ `OperatingGrossProfitWAT` | `jpigp_cor:GrossProfitIFRS` | — |
| `pl.operating_profit` | 営業利益 | `jppfs_cor:OperatingIncome` → `OperatingIncomeTotalBusiness`（全事業営業利益。鉄道単体） | `jpigp_cor:OperatingProfitLossIFRS` | 一般 |
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
| 8 | `jppfs_cor:OperatingExpensesAndCostOfSalesOfTransportationRWY` | 運輸業等営業費及び売上原価（鉄道・連結） |
| 9 | `jppfs_cor:ShippingBusinessExpensesAndOtherOperatingExpensesWAT` | 海運業費用及びその他の営業費用（海運） |
| 10 | 合算 `ShippingBusinessExpensesWAT` + `OtherBusinessExpensesWAT` | 海運（単体）: 海運業費用 + その他事業費用 |
| 11 | `jppfs_cor:CostOfProductsManufactured` | 当期製品製造原価 |

営業原価が先頭なのは、営業収益とペアの原価だから（営業収益型の企業は売上原価も併記するが、そちらは売上高側の原価になる）。当期製品製造原価が最後なのは、売上原価の代わりにこれで本表を開示する製造業がある一方、通常は製造原価明細の項目として売上原価と併記されるため。

一般の `pl.sga` のフォールバック:

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:SellingGeneralAnd` `AdministrativeExpenses` | 販売費及び一般管理費 |
| 2 | `jppfs_cor:SellingGeneralAnd` `AdministrativeExpensesGAS` | 供給販売費及び一般管理費（ガス） |
| 3 | `jppfs_cor:GeneralAnd` `AdministrativeExpensesWAT` | 一般管理費（海運） |
| 4 | `jppfs_cor:GeneralAnd` `AdministrativeExpensesSGA` | 一般管理費。本来は販管費の内訳（ガスの供給販売費及び一般管理費の内訳にも現れる）なので合計系より後ろに置き、販売費を持たず一般管理費だけを開示する持株会社等の最終手段にする |

一般の `pl.operating_expenses`（原価と販管費に分けず一括開示する業種）のフォールバック:

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:OperatingExpenses` | 営業費用（営業収益−営業費用型の一般事業会社） |
| 2 | `jppfs_cor:OperatingExpensesELE` | 営業費用（電気） |
| 3 | `jppfs_cor:OperatingExpensesSPF` | 営業費用（特定金融。金融費用・その他営業費用・売上原価を含む合計） |
| 4 | `jppfs_cor:OperatingExpensesCMD` | 営業費用（商品先物。売上原価控除後: 営業収益−売上原価=営業総利益、−営業費用=営業利益） |
| 5 | `jppfs_cor:OperatingExpensesIVT` / `OperatingExpensesINV` | 営業費用（投資運用 / 投資業） |
| 6 | `jppfs_cor:OperatingExpensesRWY` / `OperatingExpensesTotalRWY` | 営業費 / 全事業営業費（鉄道） |
| 7 | 合算 `OperatingExpenses{Railway, Railroad, Related, Incidental, SideLine, RealEstate, Development, Automobile, Other}RWY`（収益と同じ9区分） | 鉄道（単体）: 事業区分別の営業費の合計 |
| 8 | 合算 `OperatingExpensesOILTelecommunications` + `OperatingExpensesIncidentalELC` | 電気通信: 電気通信事業営業費用 + 附帯事業営業費用 |

「営業費用」の意味は業種で違う（電気・特定金融は原価・販管費を含む合計、鉄道連結の営業費は内訳と併記される合計、商品先物は原価控除後）。Builderが貸借の合う費用構成を選ぶため、Extractorは業種を問わず営業費用のタグをそのまま保存すればよく、内訳と両方保存しても重複計上にならない（[03章](03_data_flow.md)実例3）。

IFRSの営業利益（`pl.operating_profit`）は保存はするがBuilderでは使っていない。IFRSでは開示が任意で、開示する企業としない企業が混在して企業間の比較にならないため。

## CF（キャッシュ・フロー計算書）

| 科目コード | 日本語 | 一般・銀行・保険 | 分類・配列 |
|---|---|---|---|
| `cf.operating` | 営業活動によるCF | `jppfs_cor:NetCashProvidedByUsedIn` `OperatingActivities` | `jpigp_cor:NetCashProvidedByUsedIn` `OperatingActivitiesIFRS` |
| `cf.investing` | 投資活動によるCF | `jppfs_cor:NetCashProvidedByUsedIn` `InvestmentActivities` | `jpigp_cor:NetCashProvidedByUsedIn` `InvestingActivitiesIFRS` |
| `cf.financing` | 財務活動によるCF | `jppfs_cor:NetCashProvidedByUsedIn` `FinancingActivities` | `jpigp_cor:NetCashProvidedByUsedIn` `FinancingActivitiesIFRS` |
| `cf.cash_end` | 現金及び現金同等物の期末残高 | `jppfs_cor:CashAndCashEquivalents` | `jpigp_cor:CashAndCashEquivalentsIFRS` |
| `cf.cash_begin` | 同・期首残高 | 同上（`Prior1YearInstant`） | 同上（`Prior1YearInstant`） |

投資活動のタグ名が日本基準は `Investment`、IFRSは `Investing` で異なる。CFは5科目そろわないとウォーターフォールが繋がらないため、1つでも欠けるとチャートは `renderable: false` になる。

期首残高（`cf.cash_begin`）は個別のマッピングを持たない。期首残高=前期末残高という関係は全形式共通のため、Extractorの基底クラスが `cf.cash_end` と同じタグを前期末（`Prior1YearInstant`）コンテキストで引いて導出する。マッピング表（当期のコンテキスト固定）で表せない「別コンテキストの参照」は現在これだけ。

### サマリ（ifrs_summary）のタグ

詳細タグの無い有報は、経営指標サマリ（`jpcrp_cor`）の標準タグから次の7科目だけを抽出する。BS科目を保存しないのは、サマリで実値が取れるのが資産合計と親会社所有者帰属持分だけで、負債合計は導出でしか作れない（非支配持分が混ざる）ため。

| 科目コード | XBRLタグ（すべて `jpcrp_cor`） |
|---|---|
| `pl.revenue` | `RevenueIFRS` `SummaryOfBusinessResults` |
| `pl.profit_before_tax` | `ProfitLossBeforeTaxIFRS` `SummaryOfBusinessResults` |
| `cf.operating` | `CashFlowsFromUsedIn` `OperatingActivitiesIFRS` `SummaryOfBusinessResults` |
| `cf.investing` | `CashFlowsFromUsedIn` `InvestingActivitiesIFRS` `SummaryOfBusinessResults` |
| `cf.financing` | `CashFlowsFromUsedIn` `FinancingActivitiesIFRS` `SummaryOfBusinessResults` |
| `cf.cash_end` / `cf.cash_begin` | `CashAndCashEquivalentsIFRS` `SummaryOfBusinessResults`（期首は `Prior1YearInstant`） |

## 複数タグの合算の対象

合計タグを持たず内訳だけを開示する科目は、合算記法 `sum(...)`（記法の意味となぜ逆算しないかは[03章](03_data_flow.md)）で1つの科目コードにしている。現在の合算対象は次のとおり。

| 科目 | 形式 | 合算の内容 |
|---|---|---|
| のれん及び無形資産 | 分類 | `GoodwillAndIntangibleAssetsIFRS`（合算タグ。三菱商事）→ 無ければ `GoodwillIFRS` + `IntangibleAssetsIFRS`（別掲。武田） |
| 営業収益・営業費 | 一般（鉄道単体） | 鉄道事業 + 関連事業 + 兼業 + 不動産事業 + … の事業区分別タグ（企業により区分の組合せが違う） |
| 営業収益・営業費用 | 一般（電気通信） | 電気通信事業 + 附帯事業 |
| 営業収益・費用 | 一般（海運単体） | 海運業 + その他事業 |
| 売上高 + 営業収入 | 一般 | 総額タグを付けない企業の総額（`max` の内側。トップラインの表の8） |

```ruby
"bs.goodwill_and_intangibles" => [ "jpigp_cor:GoodwillAndIntangibleAssetsIFRS",
                                   sum("jpigp_cor:GoodwillIFRS", "jpigp_cor:IntangibleAssetsIFRS") ]
```

---

## 実地調査の記録

ここから後ろは、前半の対応表と[03章](03_data_flow.md)の形式判定・記法の根拠になった実測記録。EDINET API v2で実際に有報XBRLを取得し、全factをダンプして確認した。タクソノミの公式資料だけでは分からない実態が実装判断を左右するため、実物での確認記録を残している。構成は、初期実装時の基本8社・4形式 → 業種別対応で追加した実測 → 3年分の全数検証の順。

### 調査対象（基本8社・4形式）

| 企業 | 証券コード | docID | 会計基準(DEI) | 連結業種(DEI) | 判定形式 |
|---|---|---|---|---|---|
| 武田薬品工業 | 4502 | S100YB5L | IFRS | cte | ifrs_classified |
| 三菱商事 | 8058 | S100YB25 | IFRS | cte | ifrs_classified |
| ＮＴＴ | 9432 | S100YCP3 | IFRS | cte | ifrs_classified |
| 楽天グループ | 4755 | S100XTNW | IFRS | cte | ifrs_liquidity |
| 東京海上HD | 8766 | S100YLS8 | IFRS | **INS** | ifrs_liquidity |
| 三菱UFJ FG | 8306 | S100YJQO | Japan GAAP | **bnk** | jgaap_bank |
| イオン | 8267 | S100YQ6Y | Japan GAAP | cte | jgaap_general |
| インスペック | 6656 | S100YR8L | Japan GAAP | —（単体のみ。単体はCTE） | jgaap_general |

- いずれも2026年提出の有報（楽天のみ2025/12期、イオンは2026/2期、インスペックは2026/4期、他は2026/3期）
- イオン・インスペックは売上原価フォールバック対応（営業収益型・当期製品製造原価型）のために後から追加した実測
- 東京海上HDは2026/3期からIFRSへ移行済みだった（当初は日本基準・保険業のサンプルとして選定）。日本基準・保険業は後述の業種別対応でかんぽ生命等を実測した

### 実測での発見と実装への反映

| 実測での発見 | 実装への反映 |
|---|---|
| 楽天のfactダンプで `CurrentAssetsIFRS` の出現が0件（512000様式のツリー自体に流動/非流動の要素がない） | IFRSの2様式は「タグの実在」で判定する（[03章](03_data_flow.md)） |
| IFRS企業の単体財務諸表は6社すべて `jppfs_cor` + `_NonConsolidatedMember` でタグ付け | 単体は常に日本基準として処理（[03章](03_data_flow.md)） |
| NTT: 本表の収益が企業拡張タグ `jpcrp030000-asr_E04430-000:OperatingRevenuesIFRS`（営業収益14.41兆円）のみ。経営指標サマリの標準タグは本表と完全一致 | サマリタグを収益フォールバックの最後に置く（前半のPLの表） |
| 東京海上: 保険収益が拡張タグ `InsuranceRevenueIFRS`（7.69兆円）のみで、経営指標サマリの標準タグも存在しない | 標準タグだけでは取れない企業が実在する → 「PLは表示不可」を正常系にする（[03章](03_data_flow.md)実例2） |
| CFの3区分と現金同等物は全形式で取得可能（タグ名が基準別に異なるのみ） | CFチャートを全形式共通のBuilderにできる（[03章](03_data_flow.md)） |
| 銀行BSに流動/固定の区分がなく、合計だけは汎用タグ（`jppfs_cor:Assets` 等）で取れる | 銀行BSは主要科目+残差で描く（[03章](03_data_flow.md)実例1） |
| 2019年3月期より前のIFRS有報（S100SO41ほか）は `jpigp_cor` のfact自体が収録されていない（詳細タグ付けは2019年3月31日以後終了事業年度から義務化）。財務諸表の値は経営指標サマリ `jpcrp_cor:*IFRSSummaryOfBusinessResults` のみ | 資産合計タグも無いIFRS書類はサマリだけで構成する `ifrs_summary` に落とす（[03章](03_data_flow.md)）。BSはサマリに負債の実値が無いため描かず説明文にする |

### 金融庁 IFRSタクソノミ要素リスト（1g_IFRS_ElementList.xlsx）からの知見

- **511000 財政状態計算書（流動/非流動）** と **512000 財政状態計算書（流動性配列）** の2様式が公式に存在する。512000には流動/非流動の合計要素自体がない
- **521000 損益計算書**: 収益の標準要素は `RevenueIFRS` / `NetSalesIFRS` / `Revenue2IFRS` の3系列。`GrossProfitIFRS`・`OperatingProfitLossIFRS` は任意項目。経常利益・特別損益に相当する要素は存在しない。非流動負債のタイポ（`NonCurrentLabilitiesIFRS`）が公式要素名であることもこのリストで確認した
- **540000 CF計算書**: 3区分 + 増減 + 現金同等物
- 要素メタデータとして periodType（instant/duration）と balance（debit/credit）が定義されており、マッピング作成時の科目性質の確認に使える

### 検証用データ（実測値。テストの期待値に使用）

| item | 武田 S100YB5L | 三菱商事 S100YB25 | NTT S100YCP3 | 楽天 S100XTNW | 東京海上 S100YLS8 | MUFG S100YJQO |
|---|---|---|---|---|---|---|
| bs.assets | 15,511,506 | 24,151,695 | 46,721,259 | 28,804,400 | 33,002,651 | 431,731,548 |
| bs.equity | 7,430,649 | 10,250,574 | 10,217,533 | 1,354,232 | 8,052,371※1 | 23,744,152 |
| pl.revenue | 4,505,720 | 18,915,995 | 14,409,121※2 | 2,496,575 | 取得不可 | −（銀行は経常収益14,620,843） |
| pl.profit_before_tax | -142,355 | 1,096,094 | 1,581,923 | -29,550 | 750,700 | 3,322,161 |
| cf.operating | 1,041,431 | 1,490,041 | 1,485,190 | 424,093 | 1,390,562 | -23,064,420 |

単位: 百万円。※1 = 開示された資本合計（`EquityIFRS`）。内訳の親会社帰属7,955,554 + 非支配96,816 = 8,052,370とは1百万円ずれるが、これは有報側で合計と内訳が独立に百万円へ丸められているためで、3つとも開示値のまま。※2 = サマリタグからのフォールバック値。

jgaap_generalの2社は売上原価フォールバックの検証用（単位はXBRLの開示単位のまま）:

| item | イオン S100YQ6Y（百万円） | インスペック S100YR8L（千円） |
|---|---|---|
| pl.revenue | 10,715,342（`OperatingRevenue1`。`NetSales` 9,355,439ではない） | 2,478,950 |
| pl.cost_of_sales | 6,804,966（`OperatingCost`） | 1,621,713（`CostOfProductsManufactured`） |

ifrs_summaryの検証用（クリエイト・レストランツHD S100SO41、2019年2月期。単位: 百万円。すべて経営指標サマリのタグから）:

| pl.revenue | pl.profit_before_tax | cf.operating | cf.investing | cf.financing | cf.cash_begin | cf.cash_end |
|---|---|---|---|---|---|---|
| 119,281 | 3,688 | 8,364 | -4,886 | -2,900 | 12,665 | 13,248 |

### 業種別対応の実測（本番の直近1年で `unsupported` だった業種）

本番DBで直近1年（2025-08〜2026-08提出）に `unsupported` 判定だった436財務諸表の業種内訳は、建設 279 / 証券 26 / 海運 20 / 鉄道 18 / 電気 18 / 電気通信 18 / ガス 17 / 特定金融 9 / 保険 9 / 商品先物 5 / 複数コード 8 / 投資業・投資運用 2 / 米国基準 7 だった。業種ごとに代表企業の有報XBRLを取得（計77件）して前半の対応表を作り、最後に対象261有報すべてを新実装に通して確認した（結果: 主対象235件のうち225件がBS/PL/CFすべて描画可。残りは米国基準6件、収益・費用が企業拡張タグにしか無い証券2社と投資運用1社のPL、貯金が拡張タグの日本郵政のBS）。実測に使った主な有報:

| 業種（DEI） | 企業 / docID | 連結 | 単体 | 実測での発見 → 実装 |
|---|---|---|---|---|
| 建設 cns | 大成建設 S100YDJC<br>大和ハウス S100YAZ5<br>エムビーエス S100WUBZ | 一般 | 一般 | 売上高（`NetSales`）・売上原価・販管費の標準タグを持つ。完成工事高（`…CNS`）はその内訳。既存のフォールバックのままで描ける |
| 電気 ele | 東京電力HD S100YIHR<br>関西電力 S100YFXZ<br>北海道電力 S100YDWY | 一般 | 一般 | 営業収益 `OperatingRevenueELE`（`NetSales` にも同値）− 営業費用 `OperatingExpensesELE` = 営業利益。BSは電気事業固定資産等で区分し有形/無形の標準タグがない → 営業費用一括型 + 固定資産1段 |
| 鉄道 rwy | JR東日本 S100YC7N・JR西日本 S100YCFK・京王 S100YF0G・小田急 S100YIM7・東武 S100Y8FK・名鉄 S100YHOL・西鉄 S100YAAB・南海 S100YBA0・京阪 S100YCVR・神戸電鉄 S100YAZT・山陽 S100YD7X・京福 S100YEN3・秩父 S100YIV6（いずれも単体がrwy）<br>東急 S100YE63・富士急行 S100YBGE（連結もrwy） | 一般 | 一般 | 単体は鉄道事業会計規則の様式で、営業収益・営業費を事業区分別（鉄道/鉄軌道/関連/付帯/兼業/不動産/開発/自動車/その他）にしか開示せず、合計タグ（`OperatingRevenueRWY`・`OperatingRevenueTotalRWY`）を持つ企業と持たない企業がある。営業利益は `OperatingIncome` または `OperatingIncomeTotalBusiness`（全事業営業利益） → 区分の合算記法。連結（東急）は営業費 `OperatingExpensesRWY` の内訳として運輸業等営業費及び売上原価 + 販管費を併記 → 内訳優先で描く |
| 電気通信 elc | 沖縄セルラー S100Y9T5<br>KDDI S100YKG2（単体）<br>ソフトバンク S100YE76（単体）。NSD S100YEYZ・モビルス S100X6MF等のソフト会社もelcを名乗るが標準タグ | 一般 | 一般 | 電気通信事業（`…OILTelecommunications`）+ 附帯事業（`…IncidentalELC`）の2区分で開示し合計タグがない → 合算。BSは電気通信事業固定資産で区分し有形/無形の標準タグがない → 固定資産1段 |
| ガス gas | 東京瓦斯 S100YH8W<br>静岡ガス S100XTDX<br>日本瓦斯 S100YEGP<br>東邦瓦斯 S100YGFW<br>北海道瓦斯 S100YGOL<br>北陸瓦斯 S100YIW6 | 一般 | 一般 | 売上高・売上原価は標準タグ。販管費は `SellingGeneralAnd` `AdministrativeExpensesGAS`（供給販売費及び一般管理費。その内訳の一般管理費 `GeneralAndAdministrativeExpensesSGA` も併記されるため、一般管理費は合計系より後ろに置く）。単体は売上高を `SalesFromGasBusinessGAS`（ガス事業売上高）や `GasSalesGAS`（ガス売上）で開示 |
| 海運 wat | 日本郵船 S100YBT6<br>商船三井 S100YI2T<br>川崎汽船 S100YC6B<br>玉井商船 S100Y90D | 一般 | 一般 | 大手連結は標準タグ。単体・小規模は海運業収益/費用 + その他事業収益/費用の2区分（合計は `OperatingRevenue1` を持つ企業と持たない企業がある）、一般管理費は `GeneralAndAdministrativeExpensesWAT` → 合算 + フォールバック |
| 証券 sec | 大和証券G S100YCMP<br>いちよし S100YANQ<br>松井 S100YFPS<br>岡三G S100YDTC | 一般 | 一般 | 営業収益 `OperatingRevenueSEC` − 金融費用 `FinancialExpensesSEC` = 純営業収益、− 販管費（標準タグ）= 営業利益 → 金融費用を新科目 `pl.financial_expenses` に。BSは流動/固定の3分類あり。大和証券Gは売上原価が企業拡張タグのためPLのみ描けない |
| 特定金融 spf | アコム S100YBXA<br>アサックス S100YI2V<br>三菱HCキャピタル S100YF4V（単体） | 一般 | 一般 | 消費者金融は営業収益 `OperatingRevenueSPF` − 営業費用 `OperatingExpensesSPF` の一括型。アサックスは営業費用の内訳として売上原価（標準タグ）を併記 → 内訳では貸借が合わず一括で描く。リース会社の単体は売上高・売上原価・販管費の標準タグ |
| 商品先物 cmd | 小林洋行 S100YJB4<br>豊トラスティ証券 S100YJ8P<br>unbanked S100YNMZ | 一般 | 一般 | 小林洋行のみ商品先物の様式（営業収益 `OperatingRevenueCMD`（`OperatingRevenue1` にも同値）− 売上原価 = 営業総利益 − 営業費用 `OperatingExpensesCMD` = 営業利益）→ PLの費用構成「原価+営業費用」。単体は `NetSales`（商品売上高）が営業収益の内訳 → 営業収益系を売上高より先に引く。他2社は証券様式・標準タグ |
| 投資運用 ivt / 投資業 inv | スパークス S100Y7MV<br>Mマート S100Y0DB | 一般 | 一般 | スパークスは営業費用が企業拡張タグのみでPLは描けない（BS/CFは描ける）。Mマートは `OperatingRevenue1` − 汎用の `OperatingExpenses` |
| 保険 ins | かんぽ生命 S100YD29<br>第一ライフG S100YC7A<br>T&D S100Y9UP<br>ソニーFG S100YCL0<br>SBIインシュアランス S100YDWS<br>アニコム S100YFY1<br>ライフネット S100YC7R（単体） | 保険 | 保険 or 一般 | 経常収益 `OperatingIncomeINS` − 経常費用 `OperatingExpensesINS` = 経常利益。BSは有価証券・貸付金・現金及び預貯金 + 保険契約準備金。ソニーFG単体は業種コードinsだが流動/固定のある一般様式 → 流動資産タグの実在で一般に戻す |
| 複数コード | 日本郵政 S100YE7T（bnk,ins）<br>日本インシュレーション S100YG71・広島電鉄 S100YI48（cte,cns）<br>飯野海運 S100YGFN（cte,wat）<br>オウケイウェイヴ S100WS3E（cte,sec,cmd） | — | — | 先頭のコードを主たる業種として判定。日本郵政は銀行様式のPL（`OrdinaryIncomeBNK`）だが貯金が企業拡張タグのためBSは描けない。広島電鉄の単体は鉄道様式（`OperatingRevenueTotalRWY`） |
| 米国基準 | キヤノン S100XTLJ<br>小松製作所<br>オリックス S100YG5L<br>オムロン<br>野村HD<br>富士フイルムHD | unsupported | 一般 | 本表の標準タグがなく企業拡張タグのみ（対象外のまま。単体は日本基準の標準タグで描ける） |

### 3年分の全数検証（本番の直近3年）

本番の直近3年（2023-08〜2026-08提出、有報11,662件）のうち、`unsupported` を含む有報811件（財務諸表1,499件）**すべて**と、対応済み有報から形式別に無作為抽出した200件（財務諸表427件）の計1,926財務諸表を、新実装の 形式判定→Extractor→Builder に通して確認した。

| 観点 | 方法 | 結果 |
|---|---|---|
| 回帰 | 本番に保存済みの全科目（569財務諸表）と新実装の値を比較 | 値の差分は意図した変更のみ（小林洋行単体の営業収益、バローHDの売上高+営業収入）。新たに取れる科目が76件増（鉄道連結の売上原価・持株会社単体の売上高/販管費）、値が変わったものは他になし |
| 会計恒等式 | 資産=負債+純資産 / 流動+固定=資産 / 流動+固定=負債 / 営業利益+営業外=経常利益 / 経常+特別=税引前 / 税引前−税=当期純利益 / 経常収益−費用=経常利益 / CF期首+3区分=期末 | 資産・負債・経常利益系はすべて一致（1,908/1,908 等）。税引前・当期純利益の不一致27+5件は保険の契約者配当準備金繰入・電気の渇水準備金・商品先物の責任準備金・IFRSの非継続事業など**科目構造上の差**、CFの37件は為替換算差額・連結範囲変動で、いずれも抽出誤りではない |
| 経営指標サマリとの突合 | 会社自身の主要指標（`jpcrp_cor:*SummaryOfBusinessResults`）と総資産・純資産・売上高・経常利益・当期純利益・CF3区分・期末現金を比較 | 総資産 1,905/1,908、経常利益 1,839/1,839、CF 990/993 など一致。売上高の不一致は 39/1,758 で、内訳はガス単体（サマリの売上高は営業雑収益・附帯事業収益込み。本表の売上高欄=ガス事業売上高に一致）18件、鉄道・海運単体で第3の事業区分が企業拡張タグ 9件、IFRSのサマリが別概念 5件、日揮HD単体の特殊様式 3件、その他4件。いずれも単体（画面に出ない）か拡張タグ起因 |

この検証で見つかり修正したもの: 一般管理費（販管費の内訳）が供給販売費及び一般管理費（合計）より先に取れる順序、ガス単体の `GasSalesGAS`、持株会社単体の営業収入、そして「営業収益と売上高のどちらが総額かが企業で揺れる」問題（`max` の導入。メルディアDC・バローHDで実測。[03章](03_data_flow.md)）。

検証用データ（実測値。テストの期待値に使用。単位: 百万円）:

| item | 東京電力HD S100YIHR 連結 | JR東日本 S100YC7N 単体 | 東急 S100YE63 連結 | いちよし証券 S100YANQ 連結 | 沖縄セルラー S100Y9T5 連結 | かんぽ生命 S100YD29 連結 |
|---|---|---|---|---|---|---|
| pl.revenue / ordinary_revenue | 6,328,574 | 2,225,735（=2,020,442+205,293） | 1,086,179 | 24,579 | 86,348（=52,291+34,057） | 5,625,758 |
| pl.cost_of_sales | — | — | 744,710 | — | — | — |
| pl.financial_expenses | — | — | — | 71 | — | — |
| pl.sga | — | — | 238,275 | 18,347 | — | — |
| pl.operating_expenses / ordinary_expenses | 5,990,884 | 1,923,728（=1,795,414+128,314） | 982,986 | — | 67,654（=33,482+34,172） | 5,353,811 |
| pl.operating_profit / ordinary_profit | 337,689 | 302,007（`OperatingIncomeTotalBusiness`） | 103,193 | 6,160 | 18,693 | 271,946 |
| bs.non_current_assets | 13,225,805（有形/無形なし → 固定資産1段） | | | | | — |
| bs.policy_reserves | — | — | — | — | — | 48,102,350 |
