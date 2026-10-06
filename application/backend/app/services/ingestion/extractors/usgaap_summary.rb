# 米国基準: 本表の科目は企業拡張タグだけで、EDINETの標準タグがない（会社ごとの対応表が要る）。
# 標準タグがある経営指標の要約（jpcrp_cor）から、CFの3区分と現金残高、財務指標に使う総資産・
# 親会社株主に帰属する当期純利益・自己資本・売上だけを取得する。
# 要約からは負債を「総資産−純資産」の差額でしか出せず、償還可能非支配持分などが混ざるため、
# BS・PLのグラフに使う科目は取らない
class Ingestion::Extractors::UsgaapSummary < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.assets" => "jpcrp_cor:TotalAssetsUSGAAPSummaryOfBusinessResults",
    # 自己資本は親会社株主に帰属する持分だけを使う。非支配持分を含む純資産
    # （EquityIncludingPortionAttributableToNonControllingInterest…）で代えると、ROEの分母が大きくなり、
    # ほかの会社より低く出るため。タグがない年度は、会社が公表したROEを表示する
    "bs.equity_attributable_to_owners" => "jpcrp_cor:EquityAttributableToOwnersOfParentUSGAAPSummaryOfBusinessResults",
    "cf.cash_end" => "jpcrp_cor:CashAndCashEquivalentsUSGAAPSummaryOfBusinessResults"
  }.freeze

  DURATION_MAPPING = {
    "pl.revenue" => "jpcrp_cor:RevenuesUSGAAPSummaryOfBusinessResults",
    "pl.profit_attributable_to_owners" => "jpcrp_cor:NetIncomeLossAttributableToOwnersOfParentUSGAAPSummaryOfBusinessResults",
    "cf.operating" => "jpcrp_cor:CashFlowsFromUsedInOperatingActivitiesUSGAAPSummaryOfBusinessResults",
    "cf.investing" => "jpcrp_cor:CashFlowsFromUsedInInvestingActivitiesUSGAAPSummaryOfBusinessResults",
    "cf.financing" => "jpcrp_cor:CashFlowsFromUsedInFinancingActivitiesUSGAAPSummaryOfBusinessResults"
  }.freeze
end
