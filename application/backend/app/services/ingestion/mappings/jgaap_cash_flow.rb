# 日本基準のCFの期末残と、CF計算書の7行。CF計算書のタグは業種の様式（一般事業会社・銀行・保険）によらない
Ingestion::Mappings::JgaapCashFlow = Ingestion::Mappings::Section.define do
  # CF計算書の期末残に標準タグを付けていない書類がある。経営指標の要約の現金同等物の残高は同じ金額を開示するため、2番目の候補にする
  item "cf.cash_end", [ "jppfs_cor:CashAndCashEquivalents",
                        "jpcrp_cor:CashAndCashEquivalentsSummaryOfBusinessResults" ]
  item "cf.new_consolidation", "jppfs_cor:IncreaseInCashAndCashEquivalentsFromNewlyConsolidatedSubsidiaryCCE"
  # 連結範囲の変更と合併による現金の増減は、標準タグでも会社によって行の分け方が違う（連結除外に伴う減少、
  # 非連結子会社との合併に伴う増加など）。どれもCFの式（期首残＋各CF＋換算差額など＝期末残）に足す行なので、ある行を合計する
  item "cf.consolidation_change", sum("jppfs_cor:IncreaseDecreaseInCashAndCashEquivalentsResultingFromChangeOfScopeOfConsolidationCCE",
                                      "jppfs_cor:DecreaseInCashAndCashEquivalentsResultingFromExclusionOfSubsidiariesFromConsolidationCCE")
  item "cf.merger", sum("jppfs_cor:IncreaseInCashAndCashEquivalentsResultingFromMergerCCE",
                        "jppfs_cor:IncreaseInCashAndCashEquivalentsResultingFromMergerWithUnconsolidatedSubsidiariesCCE",
                        "jppfs_cor:IncreaseDecreaseInCashAndCashEquivalentsResultingFromMergerOfSubsidiariesCCE")
  item "cf.exchange_effect", "jppfs_cor:EffectOfExchangeRateChangeOnCashAndCashEquivalents"
  item "cf.operating", "jppfs_cor:NetCashProvidedByUsedInOperatingActivities"
  item "cf.investing", "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities" # 日本基準はInvestment（IFRSはInvesting。取り違え注意）
  item "cf.financing", "jppfs_cor:NetCashProvidedByUsedInFinancingActivities"
end
