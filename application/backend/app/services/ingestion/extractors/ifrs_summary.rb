# IFRS・本表の詳細タグなし（詳細タグ付け義務化=2019年3月31日以後終了事業年度より前の有報。
# jpigp_cor のfact自体が収録されていない）
#
# 財務諸表の値で唯一収録されている経営指標サマリ（jpcrp_cor）の標準タグから抽出する。
# BSチャートに必要な内訳はないが、指標で使う総資産・親会社所有者帰属持分は取得できる。
class Ingestion::Extractors::IfrsSummary < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.assets" => "jpcrp_cor:TotalAssetsIFRSSummaryOfBusinessResults",
    "bs.equity_attributable_to_owners" => "jpcrp_cor:EquityAttributableToOwnersOfParentIFRSSummaryOfBusinessResults",
    "cf.cash_end" => "jpcrp_cor:CashAndCashEquivalentsIFRSSummaryOfBusinessResults"
  }.freeze

  DURATION_MAPPING = {
    "pl.profit_attributable_to_owners" => "jpcrp_cor:ProfitLossAttributableToOwnersOfParentIFRSSummaryOfBusinessResults",
    "pl.revenue"           => "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults",
    "pl.profit_before_tax" => "jpcrp_cor:ProfitLossBeforeTaxIFRSSummaryOfBusinessResults",
    "cf.operating" => "jpcrp_cor:CashFlowsFromUsedInOperatingActivitiesIFRSSummaryOfBusinessResults",
    "cf.investing" => "jpcrp_cor:CashFlowsFromUsedInInvestingActivitiesIFRSSummaryOfBusinessResults",
    "cf.financing" => "jpcrp_cor:CashFlowsFromUsedInFinancingActivitiesIFRSSummaryOfBusinessResults"
  }.freeze
end
