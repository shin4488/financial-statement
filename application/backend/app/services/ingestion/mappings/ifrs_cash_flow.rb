# IFRSのCFの期末残と、CF計算書の行。CF計算書のタグは財政状態計算書の様式（511000・512000）によらない
Ingestion::Mappings::IfrsCashFlow = Ingestion::Mappings::Section.define do
  # CF計算書の現金及び現金同等物の残高が財政状態計算書の額と違う会社は、CF計算書の残高を2番目の標準タグで開示する。
  # CFの式（期首残＋各CF＋換算差額＝期末残）がそちらで成り立つときは、そちらを期首残・期末残にする
  item "cf.cash_end", [ "jpigp_cor:CashAndCashEquivalentsIFRS",
                        "jpigp_cor:CashAndCashEquivalentsIfDifferentFromBSBalanceIFRS" ]
  item "cf.exchange_effect", "jpigp_cor:EffectOfExchangeRateChangesOnCashAndCashEquivalentsIFRS"
  item "cf.operating", "jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS"
  item "cf.investing", "jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS" # IFRSはInvesting（日本基準はInvestment）
  item "cf.financing", "jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS"
end
