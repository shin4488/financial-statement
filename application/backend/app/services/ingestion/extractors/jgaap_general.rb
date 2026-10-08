# 日本基準・一般事業会社。
# 業種別の勘定科目を持つ業種（建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・
# 商品先物・投資業など）も財務諸表の骨格は同じなのでこの形式で扱い、タグ名の違いは
# フォールバックリストで吸収する。業種固有のタグはその業種の有報にしか現れないため、
# リストの中で業種をまたぐ優先順位を気にする必要はない（同一業種内の順序だけが意味を持つ）。
# 対応表と実測の根拠は docs/guide を参照
class Ingestion::Extractors::JgaapGeneral < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.current_assets"               => "jppfs_cor:CurrentAssets",
    "bs.tangible_fixed_assets"        => "jppfs_cor:PropertyPlantAndEquipment",
    "bs.intangible_fixed_assets"      => "jppfs_cor:IntangibleAssets",
    "bs.investments_and_other_assets" => "jppfs_cor:InvestmentsAndOtherAssets",
    "bs.non_current_assets"           => "jppfs_cor:NoncurrentAssets",
    "bs.deferred_assets"              => "jppfs_cor:DeferredAssets",
    "bs.assets"                       => "jppfs_cor:Assets",
    "bs.current_liabilities"          => "jppfs_cor:CurrentLiabilities",
    "bs.non_current_liabilities"      => "jppfs_cor:NoncurrentLiabilities",
    "bs.liabilities"                  => "jppfs_cor:Liabilities",
    "bs.equity"                       => "jppfs_cor:NetAssets",
    "bs.equity_attributable_to_owners" => Ingestion::Extractors::JgaapOwnersEquity.new,
    # 同じタグを2つの科目コードに保存する: 現金同等物はBSの科目としてもCFの期末残高としても
    # 消費される（消費先が違う）。縦持ちでは行が1つ増えるだけなので冗長保存を許容し、
    # Builder側が「どのコードを見ればよいか」で迷わないようにする
    "bs.cash_and_equivalents"         => "jppfs_cor:CashAndCashEquivalents",
    # CF計算書の期末残に標準タグを付けていない書類がある。経営指標の要約の現金同等物の残高は同じ金額を開示するため、2番目の候補にする
    "cf.cash_end"                     => [ "jppfs_cor:CashAndCashEquivalents",
                                           "jpcrp_cor:CashAndCashEquivalentsSummaryOfBusinessResults" ]
  }.freeze

  DURATION_MAPPING = {
    # トップライン。業種による科目ゆれ（営業収益・完成工事高など）をフォールバックで吸収する（順序が優先度）。
    # 業種固有の営業収益（合計タグ）を先に置く理由: 商品先物取引業のように商品売上高（NetSales）が
    # 営業収益の内訳になる業種があるため（業種固有タグはその業種の有報にしか現れない）
    "pl.revenue" => [
      "jppfs_cor:OperatingRevenueRWY",                                  # 営業収益（鉄道）
      "jppfs_cor:OperatingRevenueTotalRWY",                             # 全事業営業収益（鉄道）
      "jppfs_cor:OperatingRevenueELE",                                  # 営業収益（電気）
      "jppfs_cor:OperatingRevenueSEC",                                  # 営業収益（証券）
      "jppfs_cor:OperatingRevenueSPF",                                  # 営業収益（特定金融）
      "jppfs_cor:OperatingRevenueCMD",                                  # 営業収益（商品先物）
      "jppfs_cor:OperatingRevenueIVT",                                  # 営業収益（投資運用）
      "jppfs_cor:OperatingRevenueINV",                                  # 営業収益（投資業）
      "jppfs_cor:ShippingBusinessRevenueAndOtherOperatingRevenueWAT",   # 海運業収益及びその他の営業収益（海運）
      # 一般事業会社の総額。営業収益（OperatingRevenue1）と 売上高+営業収入（NetSales+OperatingRevenue2）は
      # 制度上は 営業収益 = 売上高 + 営業収入 だが、どれをどう付けるかは企業で揺れる:
      #   営業収益を総額に付ける小売（3タグとも） / 総額タグを付けず売上高と営業収入だけ付ける小売 /
      #   売上高を総額とし営業収益を一部の事業にだけ付ける会社 / 営業収入だけを開示する持株会社の単体 /
      #   売上高と営業収入の両方に同じ総額を付ける会社（足すと売上が2倍になるため、同じ金額なら1回だけ数える）
      # 内訳は総額を超えないので、最も包括的な値（最大）を採ればどのパターンでも総額になる
      max("jppfs_cor:OperatingRevenue1",                                # 営業収益
          sum("jppfs_cor:NetSales", "jppfs_cor:OperatingRevenue2",      # 売上高 + 営業収入
              distinct_amounts: true)),
      "jppfs_cor:Revenue",                                            # 収益（丸井グループ等）
      # ガス事業売上高は全社売上ではない。雑収益・附帯事業収益も含める（各内訳を重複加算しない）。
      max(sum("jppfs_cor:SalesFromGasBusinessGAS",
              "jppfs_cor:MiscellaneousOperatingRevenueGAS",
              "jppfs_cor:RevenueForIncidentalBusinessesGAS"),
          sum("jppfs_cor:GasSalesGAS",                                 # ガス事業合計がない場合は内訳を使う
              "jppfs_cor:ThirdPartyAccessRevenueGAS",
              "jppfs_cor:RevenueFromInteroperatorSettlementGAS",
              "jppfs_cor:MiscellaneousOperatingRevenueGAS",
              "jppfs_cor:RevenueForIncidentalBusinessesGAS")),
      "jppfs_cor:ContractsCompletedRevOA",                              # 完成工事高
      "jppfs_cor:NetSalesOfCompletedConstructionContractsCNS",          # 完成工事高（建設業）
      # 事業区分別にしか開示しない業種は区分の合算（存在する区分だけ足す。合計タグがある企業は上で先に取れる）
      sum("jppfs_cor:OperatingRevenueRailwayRWY",                       # 鉄道（単体）: 鉄道事業営業収益
          "jppfs_cor:OperatingRevenueRailroadRWY",                      #   + 鉄軌道事業営業収益
          "jppfs_cor:OperatingRevenueRelatedRWY",                       #   + 関連事業営業収益
          "jppfs_cor:OperatingRevenueIncidentalRWY",                    #   + 付帯事業営業収益
          "jppfs_cor:OperatingRevenueSideLineRWY",                      #   + 兼業営業収益
          "jppfs_cor:OperatingRevenueRealEstateRWY",                    #   + 不動産事業営業収益
          "jppfs_cor:OperatingRevenueDevelopmentRWY",                   #   + 開発事業営業収益
          "jppfs_cor:OperatingRevenueAutomobileRWY",                    #   + 自動車事業営業収益
          "jppfs_cor:OperatingRevenueOtherRWY"),                        #   + その他事業営業収益
      sum("jppfs_cor:OperatingRevenueOILTelecommunications",            # 電気通信: 電気通信事業営業収益
          "jppfs_cor:OperatingRevenueIncidentalELC"),                   #   + 附帯事業営業収益
      # 海運の一部事業が企業拡張タグの場合、標準タグの内訳合算では全社売上にならない。
      # 本表の総額がないときは、標準の経営指標サマリにある全社売上を合算より優先する。
      "jpcrp_cor:NetSalesSummaryOfBusinessResults",
      sum("jppfs_cor:ShippingBusinessRevenueWAT",                       # 海運（単体）: 海運業収益
          "jppfs_cor:OtherBusinessRevenueWAT"),                         #   + その他事業収益
      "jppfs_cor:GrossOperatingRevenue",                                # 営業総収入（売上高と営業収入の合計だけを付ける会社）
      # 売上を企業拡張タグだけで開示する会社がある。要素名は会社ごとに違い、同じ会社でも年度で変わるため、
      # 原本で売上の合計と確かめた要素名を並べる。取扱高（GrossSales）や売上の内訳の要素は売上ではないので入れない
      "filer_ext:TotalBusinessRevenueRevOA", "filer_ext:BusinessRevenues", "filer_ext:BusinessRevenue",
      "filer_ext:BusinessRevenueRevOA", "filer_ext:OperatingRevenue", "filer_ext:OperatingRevenueRevOA",
      "filer_ext:OperatingRevenuesRevOA", "filer_ext:RevenueRevOA", "filer_ext:Revenue2", "filer_ext:Proceeds",
      # 売上高の下に営業収入の内訳（不動産賃貸収入・その他の営業収入）を並べ、営業収益の合計の行にタグを付けない会社がある。
      # 売上高だけでは売上が内訳になるため、両方の行があるときの合計を、要約の売上と照合して差し替える候補に置く。
      # 売上高がある会社は上の候補で売上が取れるため、ここまで来るのは差し替えのときだけ
      sum("jppfs_cor:NetSales", "jppfs_cor:RentIncomeOfRealEstateRevOA", all_present: true),
      sum("jppfs_cor:NetSales", "jppfs_cor:OtherOperatingRevenue2RevOA", all_present: true)
    ],
    # 経営指標の要約（主要な経営指標等の推移）の売上。売上のタグに合計ではなく内訳だけを付けた書類を見つけるため、
    # 取り込んだ売上と照合する。要約に売上高と営業総収入のように内訳と総額が並ぶ会社があるため、
    # 本表の売上と同じく最も包括的な値を採る。要約の売上も企業拡張タグで開示されることがあり、要素名は会社ごとに違う
    "pl.summary_revenue" => [
      max("jpcrp_cor:NetSalesSummaryOfBusinessResults",                 # 売上高
          "jpcrp_cor:OperatingRevenue1SummaryOfBusinessResults",        # 営業収益
          "jpcrp_cor:OperatingRevenue2SummaryOfBusinessResults",        # 営業収入
          "jpcrp_cor:GrossOperatingRevenueSummaryOfBusinessResults",    # 営業総収入
          "jpcrp_cor:RevenueKeyFinancialData"),                         # 売上収益（丸井グループ等）
      filer_ext(/(Revenue|Revenues|Sales)SummaryOfBusinessResults\z/)   # 事業収益など。1株当たりの値や比率は要素名の末尾が違うため当たらない
    ],
    # 営業収入（営業収益のうち売上高以外）。売上を営業収益とした会社には、要約に売上高だけを載せる会社がある。
    # 売上から営業収入を除いた額が要約の売上高と合うかで、売上を照合する
    "pl.non_sales_operating_revenue" => "jppfs_cor:OperatingRevenue2",
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
      sum("jppfs_cor:ShippingBusinessExpensesWAT",                      # 海運（単体）: 海運業費用
          "jppfs_cor:OtherBusinessExpensesWAT"),                        #   + その他事業費用
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
      # 一般管理費は本来販管費の内訳（ガスの供給販売費及び一般管理費の内訳にも現れる）なので合計系より後ろに置く。
      # 販売費を持たず一般管理費だけを開示する持株会社等の最終手段
      # 合計タグのないガス（北海道ガス等）は供給販売費+一般管理費。他業種は一般管理費のみ。
      max(sum("jppfs_cor:SupplyAndSalesExpensesGAS", "jppfs_cor:GeneralAndAdministrativeExpensesGAS"),
          sum("jppfs_cor:SupplyAndSalesExpensesGAS", "jppfs_cor:GeneralAndAdministrativeExpensesSGA"))
    ],
    # 金融費用（証券・商品先物）: 営業収益−金融費用=純営業収益、−販管費=営業利益 の骨格を持つ業種の費用科目
    "pl.financial_expenses" => "jppfs_cor:FinancialExpensesSEC",
    # 営業費用: 原価と販管費に分けず一括開示する業種の営業費用。
    # 「営業費用」が原価・販管費を含む合計か（電気・特定金融）、内訳と併記されるか（鉄道連結）、
    # 売上原価控除後の費用か（商品先物）は業種で異なる。Builderが内訳・一括・原価+営業費用の順に
    # 貸借の合う構成を選ぶため、ここでは業種を問わず営業費用のタグをそのまま保存すればよい（PlJgaapGeneral）
    "pl.operating_expenses" => [
      "jppfs_cor:OperatingExpenses",                                    # 営業費用（営業収益−営業費用型の一般事業会社）
      "jppfs_cor:OperatingExpensesELE",                                 # 営業費用（電気）
      "jppfs_cor:OperatingExpensesSPF",                                 # 営業費用（特定金融）
      "jppfs_cor:OperatingExpensesCMD",                                 # 営業費用（商品先物。売上原価控除後）
      "jppfs_cor:OperatingExpensesIVT",                                 # 営業費用（投資運用）
      "jppfs_cor:OperatingExpensesINV",                                 # 営業費用（投資業）
      "jppfs_cor:OperatingExpensesRWY",                                 # 営業費（鉄道・連結）
      "jppfs_cor:OperatingExpensesTotalRWY",                            # 全事業営業費（鉄道）
      sum("jppfs_cor:OperatingExpensesRailwayRWY",                      # 鉄道（単体）: 鉄道事業営業費
          "jppfs_cor:OperatingExpensesRailroadRWY",                     #   + 鉄軌道事業営業費
          "jppfs_cor:OperatingExpensesRelatedRWY",                      #   + 関連事業営業費
          "jppfs_cor:OperatingExpensesIncidentalRWY",                   #   + 付帯事業営業費
          "jppfs_cor:OperatingExpensesSideLineRWY",                     #   + 兼業営業費
          "jppfs_cor:OperatingExpensesRealEstateRWY",                   #   + 不動産事業営業費
          "jppfs_cor:OperatingExpensesDevelopmentRWY",                  #   + 開発事業営業費
          "jppfs_cor:OperatingExpensesAutomobileRWY",                   #   + 自動車事業営業費
          "jppfs_cor:OperatingExpensesOtherRWY"),                       #   + その他事業営業費
      sum("jppfs_cor:OperatingExpensesOILTelecommunications",           # 電気通信: 電気通信事業営業費用
          "jppfs_cor:OperatingExpensesIncidentalELC")                   #   + 附帯事業営業費用
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
    "pl.gas_miscellaneous_expenses" => "jppfs_cor:OperatingMiscellaneousExpensesGAS",
    "pl.gas_incidental_expenses" => "jppfs_cor:ExpensesForIncidentalBusinessesGAS",
    "cf.new_consolidation" => "jppfs_cor:IncreaseInCashAndCashEquivalentsFromNewlyConsolidatedSubsidiaryCCE",
    # 連結範囲の変更と合併による現金の増減は、標準タグでも会社によって行の分け方が違う（連結除外に伴う減少、
    # 非連結子会社との合併に伴う増加など）。どれもCFの式（期首残＋各CF＋換算差額など＝期末残）に足す行なので、ある行を合計する
    "cf.consolidation_change" => sum("jppfs_cor:IncreaseDecreaseInCashAndCashEquivalentsResultingFromChangeOfScopeOfConsolidationCCE",
                                     "jppfs_cor:DecreaseInCashAndCashEquivalentsResultingFromExclusionOfSubsidiariesFromConsolidationCCE"),
    "cf.merger" => sum("jppfs_cor:IncreaseInCashAndCashEquivalentsResultingFromMergerCCE",
                       "jppfs_cor:IncreaseInCashAndCashEquivalentsResultingFromMergerWithUnconsolidatedSubsidiariesCCE",
                       "jppfs_cor:IncreaseDecreaseInCashAndCashEquivalentsResultingFromMergerOfSubsidiariesCCE"),
    "cf.exchange_effect" => "jppfs_cor:EffectOfExchangeRateChangeOnCashAndCashEquivalents",
    "cf.operating" => "jppfs_cor:NetCashProvidedByUsedInOperatingActivities",
    "cf.investing" => "jppfs_cor:NetCashProvidedByUsedInInvestmentActivities", # JGAAPはInvestment（IFRSはInvesting。取り違え注意）
    "cf.financing" => "jppfs_cor:NetCashProvidedByUsedInFinancingActivities"
  }.freeze
end
