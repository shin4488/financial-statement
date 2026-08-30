# 06. XBRLタグ対応表

【資料】「このタグはどの科目コードになり、どのグラフで使われるか」を引く対応表。XBRLタグを扱う作業のときに、**触る表（BS / PL / CF）の節だけ**開けばよい。

- 記法（フォールバック・`sum`・`max`）の意味と設計の「なぜ」、タグを追加する手順（変更ガイド）は[03章](03_data_flow.md)
- この表の根拠になった実測記録（調査対象の企業・docID・検証用の実測値）は[07章](07_taxonomy_survey.md)。対応の理由を確かめたいときだけ開けばよい

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

`NonCurrentLabilities` は綴りが誤っているように見えるが、金融庁のタクソノミ側のタイポがそのまま公式要素名になっている（確認の記録は[07章](07_taxonomy_survey.md)）。将来修正される可能性があるので、正しい綴りもフォールバックに入れてある。

一般の固定資産は「有形固定資産・無形固定資産・投資その他の資産」の3分類（次表）で描くが、電気・鉄道・電気通信の単体など業種別様式では固定資産を事業用資産（電気事業固定資産・鉄道事業固定資産など）で区分し、有形/無形の標準タグを持たない（投資その他の資産だけ標準タグで取れる）。BuilderはこのときBSを `bs.non_current_assets`（固定資産合計）の1段で描く（[03章](03_data_flow.md)）。

### 形式固有の内訳科目

| 科目コード | 日本語 | 形式 | XBRLタグ | 使うBuilder |
|---|---|---|---|---|
| `bs.tangible_fixed_assets` | 有形固定資産 | 一般 | `jppfs_cor:PropertyPlantAndEquipment` | 一般 |
| `bs.intangible_fixed_assets` | 無形固定資産 | 一般 | `jppfs_cor:IntangibleAssets` | 一般 |
| `bs.investments_and_other_assets` | 投資その他の資産 | 一般 | `jppfs_cor:InvestmentsAndOtherAssets` | 一般 |
| `bs.loans` | 貸出金 / 貸付金 | 銀行・保険 | 銀行 `jppfs_cor:LoansAndBillsDiscountedAssetsBNK`<br>保険 `jppfs_cor:LoansReceivablesAssetsINS` | 銀行・保険 |
| `bs.securities` | 有価証券 | 銀行・保険 | 銀行 `jppfs_cor:SecuritiesAssetsBNK`<br>保険 `jppfs_cor:SecuritiesAssetsINS` | 銀行・保険 |
| `bs.deposits` | 預金 | 銀行 | `jppfs_cor:DepositsLiabilitiesBNK` | 銀行 |
| `bs.policy_reserves` | 保険契約準備金 | 保険 | `jppfs_cor:ReserveForInsurancePolicyLiabilitiesLiabilitiesINS` | 保険 |
| `bs.property_plant_and_equipment` | 有形固定資産 | 分類 | `jpigp_cor:PropertyPlantAndEquipmentIFRS` | — |
| `bs.goodwill_and_intangibles` | のれん及び無形資産 | 分類 | 下記の合算処理 | — |
| `bs.equity_attributable_to_owners` | 親会社所有者帰属持分 | 分類・配列 | `jpigp_cor:EquityAttributableToOwnersOfParentIFRS` | — |
| `bs.non_controlling_interests` | 非支配持分 | 分類・配列 | `jpigp_cor:NonControllingInterestsIFRS` | — |

## PL（損益計算書）

### 全形式で共通

| 科目コード | 日本語 | 一般・銀行・保険 | 分類・配列 | 使うBuilder |
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
| 1 | `jppfs_cor:OperatingRevenueRWY` / `OperatingRevenueTotalRWY` | 営業収益 / 全事業営業収益（鉄道） |
| 2 | `jppfs_cor:OperatingRevenueELE` | 営業収益（電気） |
| 3 | `jppfs_cor:OperatingRevenueSEC` | 営業収益（証券） |
| 4 | `jppfs_cor:OperatingRevenueSPF` | 営業収益（特定金融） |
| 5 | `jppfs_cor:OperatingRevenueCMD` | 営業収益（商品先物） |
| 6 | `jppfs_cor:OperatingRevenueIVT` / `OperatingRevenueINV` | 営業収益（投資運用 / 投資業） |
| 7 | `jppfs_cor:ShippingBusinessRevenueAndOtherOperatingRevenueWAT` | 海運業収益及びその他の営業収益（海運） |
| 8 | 最大値 `max(OperatingRevenue1, NetSales + OperatingRevenue2)` | 一般事業会社の総額: 営業収益 と 売上高+営業収入 の大きい方（企業のタグ付けの揺れを吸収する。なぜ最大値かは[03章](03_data_flow.md)） |
| 9 | `jppfs_cor:SalesFromGasBusinessGAS` → `GasSalesGAS` | ガス事業売上高 → ガス売上（ガス。単体は売上高でなくこれらで開示する） |
| 10 | `jppfs_cor:ContractsCompletedRevOA` | 完成工事高 |
| 11 | `jppfs_cor:NetSalesOfCompletedConstructionContractsCNS` | 完成工事高（建設業） |
| 12 | 合算 `OperatingRevenue{Railway,Railroad,Related,Incidental,SideLine,RealEstate,Development,Automobile,Other}RWY` | 鉄道（単体）: 事業区分別の営業収益の合計 |
| 13 | 合算 `OperatingRevenueOILTelecommunications` + `OperatingRevenueIncidentalELC` | 電気通信: 電気通信事業営業収益 + 附帯事業営業収益 |
| 14 | 合算 `ShippingBusinessRevenueWAT` + `OtherBusinessRevenueWAT` | 海運（単体）: 海運業収益 + その他事業収益 |

業種固有の営業収益（1〜7）を一般の総額（8）より先に置くのは、商品先物取引業のように商品売上高（`NetSales`）が営業収益の内訳になる業種があるため（業種の接尾辞が付くタグはその業種の有報にしか現れないので、業種をまたぐ順序に意味はなく、同一業種内の「合計タグ → 区分の合算」の順序だけが効く）。

**分類・配列** — `pl.revenue`

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jpigp_cor:RevenueIFRS` | 売上収益 |
| 2 | `jpigp_cor:Revenue2IFRS` | 収益 |
| 3 | `jpigp_cor:NetSalesIFRS` | 売上高 |
| 4 | `jpcrp_cor:RevenueIFRSSummaryOfBusinessResults` | 経営指標サマリ（本表ではない） |

最後の1つだけ本表ではなく経営指標サマリから取っている。本表の収益が企業拡張タグしか無い企業（NTTなど。拡張タグを読まない方針は[03章](03_data_flow.md)）でも取得できるようにする最終フォールバックで、値は本表と一致することを実測で確認済み（[07章](07_taxonomy_survey.md)）。順番を最後にしているのは、本表のタグの方が一次情報だから。

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
| `pl.sga` | 販売費及び一般管理費 | フォールバック4件（下記） | `jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS` | 一般・IFRS |
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
| 1 | `jppfs_cor:SellingGeneralAndAdministrativeExpenses` | 販売費及び一般管理費 |
| 2 | `jppfs_cor:SellingGeneralAndAdministrativeExpensesGAS` | 供給販売費及び一般管理費（ガス） |
| 3 | `jppfs_cor:GeneralAndAdministrativeExpensesWAT` | 一般管理費（海運） |
| 4 | `jppfs_cor:GeneralAndAdministrativeExpensesSGA` | 一般管理費。本来は販管費の内訳（ガスの供給販売費及び一般管理費の内訳にも現れる）なので合計系より後ろに置き、販売費を持たず一般管理費だけを開示する持株会社等の最終手段にする |

一般の `pl.operating_expenses`（原価と販管費に分けず一括開示する業種）のフォールバック:

| 順 | XBRLタグ | 日本語 |
|---|---|---|
| 1 | `jppfs_cor:OperatingExpenses` | 営業費用（営業収益−営業費用型の一般事業会社） |
| 2 | `jppfs_cor:OperatingExpensesELE` | 営業費用（電気） |
| 3 | `jppfs_cor:OperatingExpensesSPF` | 営業費用（特定金融。金融費用・その他営業費用・売上原価を含む合計） |
| 4 | `jppfs_cor:OperatingExpensesCMD` | 営業費用（商品先物。売上原価控除後: 営業収益−売上原価=営業総利益、−営業費用=営業利益） |
| 5 | `jppfs_cor:OperatingExpensesIVT` / `OperatingExpensesINV` | 営業費用（投資運用 / 投資業） |
| 6 | `jppfs_cor:OperatingExpensesRWY` / `OperatingExpensesTotalRWY` | 営業費 / 全事業営業費（鉄道） |
| 7 | 合算 `OperatingExpenses{Railway,Railroad,Related,Incidental,SideLine,RealEstate,Development,Automobile,Other}RWY`（収益と同じ9区分） | 鉄道（単体）: 事業区分別の営業費の合計 |
| 8 | 合算 `OperatingExpensesOILTelecommunications` + `OperatingExpensesIncidentalELC` | 電気通信: 電気通信事業営業費用 + 附帯事業営業費用 |

「営業費用」の意味は業種で違う（電気・特定金融は原価・販管費を含む合計、鉄道連結の営業費は内訳と併記される合計、商品先物は原価控除後）。Builderが貸借の合う費用構成を選ぶため、Extractorは業種を問わず営業費用のタグをそのまま保存すればよく、内訳と両方保存しても重複計上にならない（[03章](03_data_flow.md)実例3）。

IFRSの営業利益（`pl.operating_profit`）は保存はするがBuilderでは使っていない。IFRSでは開示が任意で、開示する企業としない企業が混在して企業間の比較にならないため。

## CF（キャッシュ・フロー計算書）

| 科目コード | 日本語 | 一般・銀行・保険 | 分類・配列 |
|---|---|---|---|
| `cf.operating` | 営業活動によるCF | `jppfs_cor:NetCashProvidedByUsedInOperatingActivities` | `jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS` |
| `cf.investing` | 投資活動によるCF | `jppfs_cor:NetCashProvidedByUsedInInvestmentActivities` | `jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS` |
| `cf.financing` | 財務活動によるCF | `jppfs_cor:NetCashProvidedByUsedInFinancingActivities` | `jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS` |
| `cf.cash_end` | 現金及び現金同等物の期末残高 | `jppfs_cor:CashAndCashEquivalents` | `jpigp_cor:CashAndCashEquivalentsIFRS` |
| `cf.cash_begin` | 同・期首残高 | 同上（`Prior1YearInstant`） | 同上（`Prior1YearInstant`） |

投資活動のタグ名が日本基準は `Investment`、IFRSは `Investing` で異なる。CFは5科目そろわないとウォーターフォールが繋がらないため、1つでも欠けるとチャートは `renderable: false` になる。

期首残高（`cf.cash_begin`）は個別のマッピングを持たない。期首残高=前期末残高という関係は全形式共通のため、Extractorの基底クラスが `cf.cash_end` と同じタグを前期末（`Prior1YearInstant`）コンテキストで引いて導出する。マッピング表（当期のコンテキスト固定）で表せない「別コンテキストの参照」は現在これだけ。

### サマリ（ifrs_summary）のタグ

詳細タグの無い有報は、経営指標サマリ（`jpcrp_cor`）の標準タグから次の7科目だけを抽出する。BS科目を保存しないのは、サマリで実値が取れるのが資産合計と親会社所有者帰属持分だけで、負債合計は導出でしか作れない（非支配持分が混ざる）ため。

| 科目コード | XBRLタグ（すべて `jpcrp_cor`） |
|---|---|
| `pl.revenue` | `RevenueIFRSSummaryOfBusinessResults` |
| `pl.profit_before_tax` | `ProfitLossBeforeTaxIFRSSummaryOfBusinessResults` |
| `cf.operating` | `CashFlowsFromUsedInOperatingActivitiesIFRSSummaryOfBusinessResults` |
| `cf.investing` | `CashFlowsFromUsedInInvestingActivitiesIFRSSummaryOfBusinessResults` |
| `cf.financing` | `CashFlowsFromUsedInFinancingActivitiesIFRSSummaryOfBusinessResults` |
| `cf.cash_end` / `cf.cash_begin` | `CashAndCashEquivalentsIFRSSummaryOfBusinessResults`（期首は `Prior1YearInstant`） |

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
