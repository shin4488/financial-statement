# 日本基準・銀行
Ingestion::Mappings::JgaapBank = Ingestion::Mappings::Mapping.define(
  FinancialStatements::Formats::JGAAP_BANK, Ingestion::Mappings::JgaapEquity, Ingestion::Mappings::JgaapCashFlow
) do
  # 銀行は流動/固定区分がないため合計3科目 + 業種固有の内訳のみ。
  # 合計科目のタグは一般事業会社と同じ汎用タグ
  item "bs.assets",               "jppfs_cor:Assets"
  item "bs.liabilities",          "jppfs_cor:Liabilities"
  item "bs.equity",               "jppfs_cor:NetAssets"
  item "bs.loans",                "jppfs_cor:LoansAndBillsDiscountedAssetsBNK"
  item "bs.securities",           "jppfs_cor:SecuritiesAssetsBNK"
  # BSの「現金預け金」とCFの「現金及び現金同等物」は銀行では別概念のため別タグ
  # （日銀預け金等の扱いが異なる。値が一致する銀行もあるが混同しないこと）
  item "bs.cash_and_equivalents", "jppfs_cor:CashAndDueFromBanksAssetsBNK"
  # 貯金を企業拡張タグ（要素名 DepositsLiabilities）で開示する会社がある。原本で預金（貯金）の合計と確かめた要素名を最後に置く
  item "bs.deposits",             [ "jppfs_cor:DepositsLiabilitiesBNK", "filer_ext:DepositsLiabilities" ]

  # 銀行にpl.revenue（売上高）は存在しない。トップラインは経常収益。
  # OrdinaryIncome「BNK」= 経常収益、サフィックスなしOrdinaryIncome = 経常利益、と
  # 同系の名前で意味が全く違う。取り違えると桁が大きく狂う（14.6兆 vs 3.4兆）ので注意
  item "pl.ordinary_revenue",     "jppfs_cor:OrdinaryIncomeBNK"   # 経常収益
  item "pl.ordinary_expenses",    "jppfs_cor:OrdinaryExpensesBNK" # 経常費用
  item "pl.ordinary_profit",      "jppfs_cor:OrdinaryIncome"      # 経常利益（BNKなし・一般形式と同じ汎用タグ）
  item "pl.extraordinary_income", "jppfs_cor:ExtraordinaryIncome"
  item "pl.extraordinary_loss",   "jppfs_cor:ExtraordinaryLoss"
  item "pl.profit_before_tax",    "jppfs_cor:IncomeBeforeIncomeTaxes"
  item "pl.income_tax",           "jppfs_cor:IncomeTaxes"
  item "pl.profit",               "jppfs_cor:ProfitLoss"
  item "pl.profit_attributable_to_owners", "jppfs_cor:ProfitLossAttributableToOwnersOfParent"
end
