# IFRSの経営指標の要約の売上（照合用）。IFRS移行年度の要約には日本基準の売上高も並ぶため、IFRSの要素だけを候補にする
Ingestion::Mappings::IfrsSummaryRevenue = Ingestion::Mappings::Section.define do
  item "pl.summary_revenue", [ "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults",
                               filer_ext(/(Revenue|Revenues|Sales)IFRSSummaryOfBusinessResults\z/) ]
end
