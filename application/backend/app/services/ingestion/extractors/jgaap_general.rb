# 日本基準・一般事業会社
class Ingestion::Extractors::JgaapGeneral < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.current_assets"               => "jppfs_cor:CurrentAssets",
    "bs.tangible_fixed_assets"        => "jppfs_cor:PropertyPlantAndEquipment",
    "bs.intangible_fixed_assets"      => "jppfs_cor:IntangibleAssets",
    "bs.investments_and_other_assets" => "jppfs_cor:InvestmentsAndOtherAssets",
    "bs.non_current_assets"           => "jppfs_cor:NoncurrentAssets",
    "bs.assets"                       => "jppfs_cor:Assets",
    "bs.current_liabilities"          => "jppfs_cor:CurrentLiabilities",
    "bs.non_current_liabilities"      => "jppfs_cor:NoncurrentLiabilities",
    "bs.liabilities"                  => "jppfs_cor:Liabilities",
    "bs.equity"                       => "jppfs_cor:NetAssets",
    # 同じタグを2つの科目コードに保存する: 現金同等物はBSの科目としてもCFの期末残高としても
    # 消費される（消費先が違う）。縦持ちでは行が1つ増えるだけなので冗長保存を許容し、
    # Builder側が「どのコードを見ればよいか」で迷わないようにする
    "bs.cash_and_equivalents"         => "jppfs_cor:CashAndCashEquivalents",
    "cf.cash_end"                     => "jppfs_cor:CashAndCashEquivalents",
  }.freeze

  DURATION_MAPPING = {
    # 売上高は業種による科目ゆれ（完成工事高など）があるためフォールバックリストで引く（順序が優先度）。
    # OperatingRevenue1（営業収益）を売上高より先に置く理由: 営業収益型（売上高+営業収入を
    # 営業収益として開示する小売等。実測済み）は両方のタグを持ち、営業利益と貸借が合う
    # トップラインは営業収益の方であるため
    "pl.revenue" => %w[
      jppfs_cor:OperatingRevenue1
      jppfs_cor:NetSales
      jppfs_cor:ContractsCompletedRevOA
      jppfs_cor:NetSalesOfCompletedConstructionContractsCNS
    ],
    # OperatingCost（営業原価）を先頭に置く理由: OperatingRevenue1とペアの原価であり、
    # 営業収益型ではCostOfSales（売上原価）も併記されるが、そちらは売上高側の原価のため。
    # CostOfProductsManufactured（当期製品製造原価）を末尾に置く理由: 売上原価の代わりに
    # これでPL本表を開示する製造業がある（実測済み）が、通常の製造業では製造原価明細の
    # 項目として売上原価と併記されるため、CostOfSales系が取れるならそちらが正
    "pl.cost_of_sales" => %w[
      jppfs_cor:OperatingCost
      jppfs_cor:CostOfSales
      jppfs_cor:CostOfMerchandiseAndFinishedGoodsSoldCOS
      jppfs_cor:CostOfFinishedGoodsSold
      jppfs_cor:CostOfGoodsSold
      jppfs_cor:CostOfCompletedWorkCOSExpOA
      jppfs_cor:CostOfSalesOfCompletedConstructionContractsCNS
      jppfs_cor:CostOfProductsManufactured
    ],
    "pl.gross_profit"           => "jppfs_cor:GrossProfit",
    "pl.sga"                    => "jppfs_cor:SellingGeneralAndAdministrativeExpenses",
    "pl.operating_profit"       => "jppfs_cor:OperatingIncome",
    "pl.non_operating_income"   => "jppfs_cor:NonOperatingIncome",
    "pl.non_operating_expenses" => "jppfs_cor:NonOperatingExpenses",
    "pl.ordinary_profit"        => "jppfs_cor:OrdinaryIncome",
    "pl.extraordinary_income"   => "jppfs_cor:ExtraordinaryIncome",
    "pl.extraordinary_loss"     => "jppfs_cor:ExtraordinaryLoss",
    "pl.profit_before_tax"      => "jppfs_cor:IncomeBeforeIncomeTaxes",
    "pl.income_tax"             => "jppfs_cor:IncomeTaxes",
    "pl.profit"                 => "jppfs_cor:ProfitLoss",
    "pl.profit_attributable_to_owners" => "jppfs_cor:ProfitLossAttributableToOwnersOfParent",
    "cf.operating" => "jppfs_cor:NetCashProvidedByUsedInOperatingActivities",
    "cf.investing" => "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities", # JGAAPはInvestment（IFRSはInvesting。取り違え注意）
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities",
  }.freeze

  private
    def extract_extras(result)
      # CF期首残高だけは「前期末時点」= Prior1YearInstant コンテキストを見る必要があるため
      # マッピング表（CurrentYear固定）に載せられずここで実装（全Extractor共通のパターン）
      put(result, "cf.cash_begin",
          @xbrl.money("jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant#{@c}"))
    end
end
