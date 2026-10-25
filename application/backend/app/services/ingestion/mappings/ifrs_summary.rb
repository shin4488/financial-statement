# IFRS・本表の詳細タグなし（詳細タグ付け義務化=2019年3月31日以後終了事業年度より前の有報。
# jpigp_cor のfact自体が収録されていない）
#
# 財務諸表の値で唯一収録されている経営指標サマリ（jpcrp_cor）の標準タグから抽出する（総資産だけは企業拡張タグも候補にする）。
# BSチャートに必要な内訳はないが、指標で使う総資産・親会社所有者帰属持分は取得できる。
# 売上自体が要約の値だが、売上を照合する形式を揃えるため、要約の売上も同じ候補で保存する（IfrsSummaryRevenue）
Ingestion::Mappings::IfrsSummary = Ingestion::Mappings::Mapping.define(
  FinancialStatements::Formats::IFRS_SUMMARY, Ingestion::Mappings::IfrsSummaryRevenue
) do
  # 総資産を企業拡張タグ（要素名 TotalAssets）で開示する会社がある。原本で、要約の親会社所有者帰属持分比率と合う連結の総資産と
  # 確かめた要素名を最後に置く。期首の総資産も同じ候補で前期末から取る
  item "bs.assets", [ "jpcrp_cor:TotalAssetsIFRSSummaryOfBusinessResults", "filer_ext:TotalAssets" ]
  item "bs.equity_attributable_to_owners", "jpcrp_cor:EquityAttributableToOwnersOfParentIFRSSummaryOfBusinessResults"
  item "cf.cash_end", "jpcrp_cor:CashAndCashEquivalentsIFRSSummaryOfBusinessResults"

  item "pl.profit_attributable_to_owners", "jpcrp_cor:ProfitLossAttributableToOwnersOfParentIFRSSummaryOfBusinessResults"
  item "pl.revenue",           "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults"
  item "pl.profit_before_tax", "jpcrp_cor:ProfitLossBeforeTaxIFRSSummaryOfBusinessResults"
  item "cf.operating", "jpcrp_cor:CashFlowsFromUsedInOperatingActivitiesIFRSSummaryOfBusinessResults"
  item "cf.investing", "jpcrp_cor:CashFlowsFromUsedInInvestingActivitiesIFRSSummaryOfBusinessResults"
  item "cf.financing", "jpcrp_cor:CashFlowsFromUsedInFinancingActivitiesIFRSSummaryOfBusinessResults"
end
