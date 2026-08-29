# IFRS・本表の詳細タグなし（詳細タグ付け義務化=2019年3月31日以後終了事業年度より前の有報。
# jpigp_cor のfact自体が収録されていない）
#
# 財務諸表の値で唯一収録されている経営指標サマリ（jpcrp_cor）の標準タグから抽出する。
# BSを抽出しない理由: サマリで実値が取れるのは資産合計と親会社所有者帰属持分だけで、
# 負債合計は導出でしか作れない（非支配持分が混ざった値になる）ため、実値と確信できる科目に絞る
class Ingestion::Extractors::IfrsSummary < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "cf.cash_end" => "jpcrp_cor:CashAndCashEquivalentsIFRSSummaryOfBusinessResults"
  }.freeze

  DURATION_MAPPING = {
    "pl.revenue"           => "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults",
    "pl.profit_before_tax" => "jpcrp_cor:ProfitLossBeforeTaxIFRSSummaryOfBusinessResults",
    "cf.operating" => "jpcrp_cor:CashFlowsFromUsedInOperatingActivitiesIFRSSummaryOfBusinessResults",
    "cf.investing" => "jpcrp_cor:CashFlowsFromUsedInInvestingActivitiesIFRSSummaryOfBusinessResults",
    "cf.financing" => "jpcrp_cor:CashFlowsFromUsedInFinancingActivitiesIFRSSummaryOfBusinessResults"
  }.freeze

  private
    def extract_extras(result)
      put(result, "cf.cash_begin",
          @xbrl.money("jpcrp_cor:CashAndCashEquivalentsIFRSSummaryOfBusinessResults", "Prior1YearInstant#{@c}"))
    end
end
