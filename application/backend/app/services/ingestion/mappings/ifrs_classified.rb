# IFRS・流動/非流動分類BS（タクソノミ様式511000）
Ingestion::Mappings::IfrsClassified = Ingestion::Mappings::Mapping.define(
  FinancialStatements::Formats::IFRS_CLASSIFIED,
  Ingestion::Mappings::IfrsProfitLoss, Ingestion::Mappings::IfrsSummaryRevenue, Ingestion::Mappings::IfrsCashFlow
) do
  item "bs.current_assets",          "jpigp_cor:CurrentAssetsIFRS"
  item "bs.non_current_assets",      "jpigp_cor:NonCurrentAssetsIFRS"
  item "bs.assets",                  "jpigp_cor:AssetsIFRS"
  item "bs.current_liabilities",     %w[jpigp_cor:TotalCurrentLiabilitiesIFRS jpigp_cor:CurrentLiabilitiesIFRS]
  # NonCurrentLabilities はタクソノミ公式のタイポ（1g_IFRS_ElementList.xlsxで確認済み）。
  # 将来修正された場合に備え正しい綴りもフォールバックに入れておく
  item "bs.non_current_liabilities", %w[jpigp_cor:NonCurrentLabilitiesIFRS jpigp_cor:NonCurrentLiabilitiesIFRS]
  item "bs.liabilities",             "jpigp_cor:LiabilitiesIFRS"
  item "bs.equity",                  "jpigp_cor:EquityIFRS"
  item "bs.equity_attributable_to_owners", "jpigp_cor:EquityAttributableToOwnersOfParentIFRS"
  item "bs.non_controlling_interests",     "jpigp_cor:NonControllingInterestsIFRS"
  item "bs.property_plant_and_equipment",  "jpigp_cor:PropertyPlantAndEquipmentIFRS"
  # のれん・無形: 合算タグを開示する企業と、のれん/無形を別掲する企業があるため、
  # 合算タグ優先 → なければ別掲2タグの合算で1コードに正規化する
  item "bs.goodwill_and_intangibles",      [ "jpigp_cor:GoodwillAndIntangibleAssetsIFRS",
                                             sum("jpigp_cor:GoodwillIFRS", "jpigp_cor:IntangibleAssetsIFRS") ]
  item "bs.cash_and_equivalents",    "jpigp_cor:CashAndCashEquivalentsIFRS"
end
