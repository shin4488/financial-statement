# 米国基準: 本表の科目は企業拡張タグだけで、EDINETの標準タグがない（会社ごとの対応表が要る）。
# 標準タグがある経営指標の要約（jpcrp_cor）から、CFの3区分と現金残高、財務指標に使う総資産・
# 親会社株主に帰属する当期純利益・自己資本・売上だけを取得する。
# 要約からは負債を「総資産−純資産」の差額でしか出せず、償還可能非支配持分などが混ざるため、
# BS・PLのグラフに使う科目は取らない
Ingestion::Mappings::UsgaapSummary = Ingestion::Mappings::Mapping.define(FinancialStatements::Formats::USGAAP_SUMMARY) do
  item "bs.assets", "jpcrp_cor:TotalAssetsUSGAAPSummaryOfBusinessResults"
  # 自己資本は親会社株主に帰属する持分だけを使う。非支配持分を含む純資産
  # （EquityIncludingPortionAttributableToNonControllingInterest…）で代えると、ROEの分母が大きくなり、
  # ほかの会社より低く出るため。タグがない年度は、会社が公表したROEを表示する
  item "bs.equity_attributable_to_owners", "jpcrp_cor:EquityAttributableToOwnersOfParentUSGAAPSummaryOfBusinessResults"
  item "cf.cash_end", "jpcrp_cor:CashAndCashEquivalentsUSGAAPSummaryOfBusinessResults"

  item "pl.revenue", "jpcrp_cor:RevenuesUSGAAPSummaryOfBusinessResults"
  item "pl.profit_attributable_to_owners", "jpcrp_cor:NetIncomeLossAttributableToOwnersOfParentUSGAAPSummaryOfBusinessResults"
  item "cf.operating", "jpcrp_cor:CashFlowsFromUsedInOperatingActivitiesUSGAAPSummaryOfBusinessResults"
  item "cf.investing", "jpcrp_cor:CashFlowsFromUsedInInvestingActivitiesUSGAAPSummaryOfBusinessResults"
  item "cf.financing", "jpcrp_cor:CashFlowsFromUsedInFinancingActivitiesUSGAAPSummaryOfBusinessResults"
end
