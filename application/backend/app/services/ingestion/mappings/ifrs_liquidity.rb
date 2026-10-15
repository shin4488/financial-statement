# IFRS・流動性配列BS（タクソノミ様式512000。流動/非流動の要素自体が存在しない）
#
# 財政状態計算書は IfrsClassified と似るが部品にして共有しない（共有すると一方の変更が暗黙にもう一方へ波及し、
# 形式ごとに独立して保守できなくなるため）。2様式で本当に共通と確認できているPL/CFだけを部品で共有する
Ingestion::Mappings::IfrsLiquidity = Ingestion::Mappings::Mapping.define(
  FinancialStatements::Formats::IFRS_LIQUIDITY,
  Ingestion::Mappings::IfrsProfitLoss, Ingestion::Mappings::IfrsSummaryRevenue, Ingestion::Mappings::IfrsCashFlow
) do
  item "bs.assets",                        "jpigp_cor:AssetsIFRS"
  item "bs.liabilities",                   "jpigp_cor:LiabilitiesIFRS"
  item "bs.equity",                        "jpigp_cor:EquityIFRS"
  item "bs.equity_attributable_to_owners", "jpigp_cor:EquityAttributableToOwnersOfParentIFRS"
  item "bs.non_controlling_interests",     "jpigp_cor:NonControllingInterestsIFRS"
  item "bs.cash_and_equivalents",          "jpigp_cor:CashAndCashEquivalentsIFRS"
end
