# 日本基準・保険（生命保険業・損害保険業）。
# 銀行と同じく流動/固定の区分がなく、PLは経常収益−経常費用=経常利益 の骨格。
# JgaapBankと似るが部品にして共有しない（共有すると一方の変更が暗黙にもう一方へ波及し、
# 形式ごとに独立して保守できなくなるため。共通タグの重複は許容する）
Ingestion::Mappings::JgaapInsurance = Ingestion::Mappings::Mapping.define(
  FinancialStatements::Formats::JGAAP_INSURANCE, Ingestion::Mappings::JgaapEquity, Ingestion::Mappings::JgaapCashFlow
) do
  # 合計3科目は一般事業会社と同じ汎用タグ
  item "bs.assets",               "jppfs_cor:Assets"
  item "bs.liabilities",          "jppfs_cor:Liabilities"
  item "bs.equity",               "jppfs_cor:NetAssets"
  # 保険のBS「現金及び預貯金」。銀行の現金預け金と同様、CFの現金同等物とは別概念のため別タグ
  item "bs.cash_and_equivalents", "jppfs_cor:CashAndDepositsAssetsINS"
  item "bs.securities",           "jppfs_cor:SecuritiesAssetsINS"        # 有価証券（保険会社の資産の大半）
  item "bs.loans",                "jppfs_cor:LoansReceivablesAssetsINS"  # 貸付金
  item "bs.policy_reserves",      "jppfs_cor:ReserveForInsurancePolicyLiabilitiesLiabilitiesINS" # 保険契約準備金（負債の大半）

  # 保険にpl.revenue（売上高）は存在しない。トップラインは経常収益。
  # 経常収益のタグ名が OperatingIncome「INS」で、一般形式の営業利益（OperatingIncome）と
  # 同系の名前だが意味が全く違う（銀行の OrdinaryIncomeBNK=経常収益 と同じ罠）。取り違えに注意
  item "pl.ordinary_revenue",     "jppfs_cor:OperatingIncomeINS"   # 経常収益
  item "pl.ordinary_expenses",    "jppfs_cor:OperatingExpensesINS" # 経常費用
  item "pl.ordinary_profit",      "jppfs_cor:OrdinaryIncome"       # 経常利益（INSなし・一般形式と同じ汎用タグ）
  item "pl.extraordinary_income", "jppfs_cor:ExtraordinaryIncome"
  item "pl.extraordinary_loss",   "jppfs_cor:ExtraordinaryLoss"
  item "pl.profit_before_tax",    "jppfs_cor:IncomeBeforeIncomeTaxes"
  item "pl.income_tax",           "jppfs_cor:IncomeTaxes"
  item "pl.profit",               "jppfs_cor:ProfitLoss"
  item "pl.profit_attributable_to_owners", "jppfs_cor:ProfitLossAttributableToOwnersOfParent"
end
