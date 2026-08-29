# 日本基準・保険（生命保険業・損害保険業）。
# 銀行と同じく流動/固定の区分がなく、PLは経常収益−経常費用=経常利益 の骨格。
# JgaapBankと似るが継承で差分定義しない（継承だと親の変更が暗黙に子へ波及し、
# 形式ごとに独立して保守できなくなるため。共通タグの重複は許容する）
class Ingestion::Extractors::JgaapInsurance < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    # 合計3科目は一般事業会社と同じ汎用タグ
    "bs.assets"               => "jppfs_cor:Assets",
    "bs.liabilities"          => "jppfs_cor:Liabilities",
    "bs.equity"               => "jppfs_cor:NetAssets",
    # 保険のBS「現金及び預貯金」。銀行の現金預け金と同様、CFの現金同等物とは別概念のため別タグ
    "bs.cash_and_equivalents" => "jppfs_cor:CashAndDepositsAssetsINS",
    "bs.securities"           => "jppfs_cor:SecuritiesAssetsINS",        # 有価証券（保険会社の資産の大半）
    "bs.loans"                => "jppfs_cor:LoansReceivablesAssetsINS",  # 貸付金
    "bs.policy_reserves"      => "jppfs_cor:ReserveForInsurancePolicyLiabilitiesLiabilitiesINS", # 保険契約準備金（負債の大半）
    "cf.cash_end"             => "jppfs_cor:CashAndCashEquivalents"
  }.freeze

  DURATION_MAPPING = {
    # 保険にpl.revenue（売上高）は存在しない。トップラインは経常収益。
    # 経常収益のタグ名が OperatingIncome「INS」で、一般形式の営業利益（OperatingIncome）と
    # 同系の名前だが意味が全く違う（銀行の OrdinaryIncomeBNK=経常収益 と同じ罠）。取り違えに注意
    "pl.ordinary_revenue"   => "jppfs_cor:OperatingIncomeINS",   # 経常収益
    "pl.ordinary_expenses"  => "jppfs_cor:OperatingExpensesINS", # 経常費用
    "pl.ordinary_profit"    => "jppfs_cor:OrdinaryIncome",       # 経常利益（INSなし・一般形式と同じ汎用タグ）
    "pl.extraordinary_income" => "jppfs_cor:ExtraordinaryIncome",
    "pl.extraordinary_loss"   => "jppfs_cor:ExtraordinaryLoss",
    "pl.profit_before_tax"  => "jppfs_cor:IncomeBeforeIncomeTaxes",
    "pl.income_tax"         => "jppfs_cor:IncomeTaxes",
    "pl.profit"             => "jppfs_cor:ProfitLoss",
    "pl.profit_attributable_to_owners" => "jppfs_cor:ProfitLossAttributableToOwnersOfParent",
    "cf.operating" => "jppfs_cor:NetCashProvidedByUsedInOperatingActivities",
    "cf.investing" => "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities",
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities"
  }.freeze
end
