# 日本基準・銀行
class Ingestion::Extractors::JgaapBank < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    # 銀行は流動/固定区分がないため合計3科目 + 業種固有の内訳のみ。
    # 合計科目のタグは一般事業会社と同じ汎用タグ
    "bs.assets"               => "jppfs_cor:Assets",
    "bs.liabilities"          => "jppfs_cor:Liabilities",
    "bs.equity"               => "jppfs_cor:NetAssets",
    "bs.loans"                => "jppfs_cor:LoansAndBillsDiscountedAssetsBNK",
    "bs.securities"           => "jppfs_cor:SecuritiesAssetsBNK",
    # BSの「現金預け金」とCFの「現金及び現金同等物」は銀行では別概念のため別タグ
    # （日銀預け金等の扱いが異なる。値が一致する銀行もあるが混同しないこと）
    "bs.cash_and_equivalents" => "jppfs_cor:CashAndDueFromBanksAssetsBNK",
    "bs.deposits"             => "jppfs_cor:DepositsLiabilitiesBNK",
    "cf.cash_end"             => "jppfs_cor:CashAndCashEquivalents"
  }.freeze

  DURATION_MAPPING = {
    # 銀行にpl.revenue（売上高）は存在しない。トップラインは経常収益。
    # OrdinaryIncome「BNK」= 経常収益、サフィックスなしOrdinaryIncome = 経常利益、と
    # 同系の名前で意味が全く違う。取り違えると桁が大きく狂う（14.6兆 vs 3.4兆）ので注意
    "pl.ordinary_revenue"   => "jppfs_cor:OrdinaryIncomeBNK",   # 経常収益
    "pl.ordinary_expenses"  => "jppfs_cor:OrdinaryExpensesBNK", # 経常費用
    "pl.ordinary_profit"    => "jppfs_cor:OrdinaryIncome",      # 経常利益（BNKなし・一般形式と同じ汎用タグ）
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
