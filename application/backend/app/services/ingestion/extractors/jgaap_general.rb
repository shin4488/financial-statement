# 日本基準・一般事業会社。
# 業種別の勘定科目を持つ業種（建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・
# 商品先物・投資業など）も財務諸表の骨格は同じなのでこの形式で扱い、タグ名の違いは
# フォールバックリストで吸収する。業種固有のタグはその業種の有報にしか現れないため、
# リストの中で業種をまたぐ優先順位を気にする必要はない（同一業種内の順序だけが意味を持つ）。
# 実測の根拠と対応表は docs/guide/07_taxonomy_mapping.md
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
    "cf.cash_end"                     => "jppfs_cor:CashAndCashEquivalents"
  }.freeze

  # 事業区分ごとに営業収益・営業費を分けて開示し、合計タグを持たない業種の区分一覧
  # （合算はExtractors::Baseの sum を使う。区分の有無は企業ごとに違うため存在するものだけ足す）
  RAILWAY_SEGMENTS = %w[Railway Railroad Related Incidental SideLine RealEstate Development Automobile Other].freeze # 鉄道事業会計規則
  TELECOM_SEGMENTS = %w[OILTelecommunications IncidentalELC].freeze # 電気通信事業（電気通信事業 + 附帯事業）
  SHIPPING_SEGMENTS = %w[ShippingBusiness OtherBusiness].freeze     # 海運事業（海運業 + その他事業）

  DURATION_MAPPING = {
    # トップライン。業種による科目ゆれ（営業収益・完成工事高など）をフォールバックで吸収する（順序が優先度）。
    # 営業収益系を売上高（NetSales）より先に置く理由: 営業収益型（売上高+営業収入を営業収益として
    # 開示する小売等）や商品先物取引業（商品売上高が営業収益の内訳）は両方のタグを持ち、
    # 営業利益と貸借が合うトップラインは営業収益の方であるため
    "pl.revenue" => [
      "jppfs_cor:OperatingRevenue1",                                    # 営業収益
      "jppfs_cor:OperatingRevenueRWY",                                  # 営業収益（鉄道）
      "jppfs_cor:OperatingRevenueTotalRWY",                             # 全事業営業収益（鉄道）
      "jppfs_cor:OperatingRevenueELE",                                  # 営業収益（電気）
      "jppfs_cor:OperatingRevenueSEC",                                  # 営業収益（証券）
      "jppfs_cor:OperatingRevenueSPF",                                  # 営業収益（特定金融）
      "jppfs_cor:OperatingRevenueCMD",                                  # 営業収益（商品先物）
      "jppfs_cor:OperatingRevenueIVT",                                  # 営業収益（投資運用）
      "jppfs_cor:OperatingRevenueINV",                                  # 営業収益（投資業）
      "jppfs_cor:ShippingBusinessRevenueAndOtherOperatingRevenueWAT",   # 海運業収益及びその他の営業収益（海運）
      "jppfs_cor:NetSales",                                             # 売上高
      "jppfs_cor:SalesFromGasBusinessGAS",                              # ガス事業売上高（ガス。単体は売上高でなくこれで開示する）
      "jppfs_cor:GasSalesGAS",                                          # ガス売上（ガス。ガス事業売上高の内訳だが、これしか開示しない単体がある）
      "jppfs_cor:ContractsCompletedRevOA",                              # 完成工事高
      "jppfs_cor:NetSalesOfCompletedConstructionContractsCNS",          # 完成工事高（建設業）
      # 事業区分別にしか開示しない業種は区分の合算（合計タグがある企業は上で先に取れる）
      sum(*RAILWAY_SEGMENTS.map { |s| "jppfs_cor:OperatingRevenue#{s}RWY" }),   # 鉄道（単体）: 鉄道事業+関連事業など
      sum(*TELECOM_SEGMENTS.map { |s| "jppfs_cor:OperatingRevenue#{s}" }),      # 電気通信: 電気通信事業+附帯事業
      sum(*SHIPPING_SEGMENTS.map { |s| "jppfs_cor:#{s}RevenueWAT" }),           # 海運（単体）: 海運業収益+その他事業収益
      # 営業収入は本来「売上高+営業収入=営業収益」の内訳だが、営業収入だけを開示する持株会社の単体があるため最後に置く
      "jppfs_cor:OperatingRevenue2"                                     # 営業収入
    ],
    # 売上原価。OperatingCost（営業原価）を先頭に置く理由: OperatingRevenue1とペアの原価であり、
    # 営業収益型ではCostOfSales（売上原価）も併記されるが、そちらは売上高側の原価のため。
    # CostOfProductsManufactured（当期製品製造原価）を末尾に置く理由: 売上原価の代わりに
    # これでPL本表を開示する製造業があるが、通常の製造業では製造原価明細の
    # 項目として売上原価と併記されるため、CostOfSales系が取れるならそちらが正
    "pl.cost_of_sales" => [
      "jppfs_cor:OperatingCost",                                        # 営業原価
      "jppfs_cor:CostOfSales",                                          # 売上原価
      "jppfs_cor:CostOfMerchandiseAndFinishedGoodsSoldCOS",             # 商品及び製品売上原価
      "jppfs_cor:CostOfFinishedGoodsSold",                              # 製品売上原価
      "jppfs_cor:CostOfGoodsSold",                                      # 商品売上原価
      "jppfs_cor:CostOfCompletedWorkCOSExpOA",                          # 完成工事原価
      "jppfs_cor:CostOfSalesOfCompletedConstructionContractsCNS",       # 完成工事原価（建設業）
      "jppfs_cor:OperatingExpensesAndCostOfSalesOfTransportationRWY",   # 運輸業等営業費及び売上原価（鉄道・連結）
      "jppfs_cor:ShippingBusinessExpensesAndOtherOperatingExpensesWAT", # 海運業費用及びその他の営業費用（海運）
      sum(*SHIPPING_SEGMENTS.map { |s| "jppfs_cor:#{s}ExpensesWAT" }),          # 海運（単体）: 海運業費用+その他事業費用
      "jppfs_cor:CostOfProductsManufactured"                            # 当期製品製造原価
    ],
    "pl.gross_profit" => [
      "jppfs_cor:GrossProfit",                                          # 売上総利益
      "jppfs_cor:OperatingGrossProfit",                                 # 営業総利益（営業収益型）
      "jppfs_cor:OperatingGrossProfitWAT"                               # 営業総利益（海運）
    ],
    "pl.sga" => [
      "jppfs_cor:SellingGeneralAndAdministrativeExpenses",              # 販売費及び一般管理費
      "jppfs_cor:SellingGeneralAndAdministrativeExpensesGAS",           # 供給販売費及び一般管理費（ガス）
      "jppfs_cor:GeneralAndAdministrativeExpensesWAT",                  # 一般管理費（海運）
      # 商品先物取引業の営業費用は売上原価控除後の費用（営業収益−売上原価=営業総利益、−営業費用=営業利益）で
      # 販管費に相当するため、一括型の営業費用（pl.operating_expenses）ではなくこちらに置く
      "jppfs_cor:OperatingExpensesCMD",                                 # 営業費用（商品先物）
      # 一般管理費は本来販管費の内訳（ガスの供給販売費及び一般管理費の内訳にも現れる）なので合計系より後ろに置く。
      # 販売費を持たず一般管理費だけを開示する持株会社等の最終手段
      "jppfs_cor:GeneralAndAdministrativeExpensesSGA"                   # 一般管理費
    ],
    # 金融費用（証券・商品先物）: 営業収益−金融費用=純営業収益、−販管費=営業利益 の骨格を持つ業種の費用科目
    "pl.financial_expenses" => "jppfs_cor:FinancialExpensesSEC",
    # 営業費用（一括型）: 原価と販管費に分けず営業費用を一括開示する業種。
    # 内訳と併記する企業（鉄道連結の営業費など）ではBuilderが内訳を優先する（PlJgaapGeneral）
    "pl.operating_expenses" => [
      "jppfs_cor:OperatingExpenses",                                    # 営業費用（営業収益−営業費用型の一般事業会社）
      "jppfs_cor:OperatingExpensesELE",                                 # 営業費用（電気）
      "jppfs_cor:OperatingExpensesSPF",                                 # 営業費用（特定金融）
      "jppfs_cor:OperatingExpensesIVT",                                 # 営業費用（投資運用）
      "jppfs_cor:OperatingExpensesINV",                                 # 営業費用（投資業）
      "jppfs_cor:OperatingExpensesRWY",                                 # 営業費（鉄道・連結）
      "jppfs_cor:OperatingExpensesTotalRWY",                            # 全事業営業費（鉄道）
      sum(*RAILWAY_SEGMENTS.map { |s| "jppfs_cor:OperatingExpenses#{s}RWY" }),  # 鉄道（単体）: 鉄道事業営業費+関連事業営業費など
      sum(*TELECOM_SEGMENTS.map { |s| "jppfs_cor:OperatingExpenses#{s}" })      # 電気通信: 電気通信事業営業費用+附帯事業営業費用
    ],
    "pl.operating_profit" => [
      "jppfs_cor:OperatingIncome",                                      # 営業利益
      "jppfs_cor:OperatingIncomeTotalBusiness"                          # 全事業営業利益（鉄道・単体で事業区分別に開示する企業）
    ],
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
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities"
  }.freeze

  private
    def extract_extras(result)
      # CF期首残高だけは「前期末時点」= Prior1YearInstant コンテキストを見る必要があるため
      # マッピング表（CurrentYear固定）に載せられずここで実装（全Extractor共通のパターン）
      put(result, "cf.cash_begin",
          @xbrl.money("jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant#{@c}"))
    end
end
