# IFRS・流動/非流動分類BS（タクソノミ様式511000）
class Ingestion::Extractors::IfrsClassified < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.current_assets"          => "jpigp_cor:CurrentAssetsIFRS",
    "bs.non_current_assets"      => "jpigp_cor:NonCurrentAssetsIFRS",
    "bs.assets"                  => "jpigp_cor:AssetsIFRS",
    "bs.current_liabilities"     => %w[jpigp_cor:TotalCurrentLiabilitiesIFRS jpigp_cor:CurrentLiabilitiesIFRS],
    # NonCurrentLabilities はタクソノミ公式のタイポ（1g_IFRS_ElementList.xlsxで確認済み）。
    # 将来修正された場合に備え正しい綴りもフォールバックに入れておく
    "bs.non_current_liabilities" => %w[jpigp_cor:NonCurrentLabilitiesIFRS jpigp_cor:NonCurrentLiabilitiesIFRS],
    "bs.liabilities"             => "jpigp_cor:LiabilitiesIFRS",
    "bs.equity"                  => "jpigp_cor:EquityIFRS",
    "bs.equity_attributable_to_owners" => "jpigp_cor:EquityAttributableToOwnersOfParentIFRS",
    "bs.non_controlling_interests"     => "jpigp_cor:NonControllingInterestsIFRS",
    "bs.property_plant_and_equipment"  => "jpigp_cor:PropertyPlantAndEquipmentIFRS",
    # のれん・無形: 合算タグを開示する企業と、のれん/無形を別掲する企業があるため、
    # 合算タグ優先 → なければ別掲2タグの合算で1コードに正規化する
    "bs.goodwill_and_intangibles"      => [ "jpigp_cor:GoodwillAndIntangibleAssetsIFRS",
                                            sum("jpigp_cor:GoodwillIFRS", "jpigp_cor:IntangibleAssetsIFRS") ],
    "bs.cash_and_equivalents"    => "jpigp_cor:CashAndCashEquivalentsIFRS",
    "cf.cash_end"                => "jpigp_cor:CashAndCashEquivalentsIFRS"
  }.freeze

  DURATION_MAPPING = {
    # 収益: 標準3系列 → 最後に経営指標サマリ。
    # サマリを入れる理由: 本表の収益が企業拡張タグのみの企業があり、標準タグでは取れない。
    # サマリの値は本表と一致する。
    # サマリを最後に置く理由: 本表タグの方が一次情報であり、サマリは表示単位変更などの
    # リスクが理論上あるため、あくまでフォールバック。
    # サマリにもない会社は、原本で収益の合計と確かめた企業拡張タグの要素名で探す（日本基準と同じ考え方）
    "pl.revenue" => %w[
      jpigp_cor:RevenueIFRS
      jpigp_cor:Revenue2IFRS
      jpigp_cor:NetSalesIFRS
      jpcrp_cor:RevenueIFRSSummaryOfBusinessResults
      filer_ext:OperatingRevenuesIFRS
      filer_ext:OperatingRevenueIFRS
      filer_ext:TotalNetRevenuesIFRS
    ],
    # 経営指標の要約の売上（照合用）。IFRS移行年度の要約には日本基準の売上高も並ぶため、IFRSの要素だけを候補にする
    "pl.summary_revenue" => [
      "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults",
      filer_ext(/(Revenue|Revenues|Sales)IFRSSummaryOfBusinessResults\z/)
    ],
    "pl.other_operating_income" => [ "jpigp_cor:OtherOperatingIncomeIFRS", "jpigp_cor:OtherIncomeIFRS" ],
    "pl.other_operating_expenses" => [ "jpigp_cor:OtherOperatingExpensesIFRS", "jpigp_cor:OtherExpensesIFRS" ],
    "pl.other_income_expenses_net" => "jpigp_cor:OtherIncomeExpensesNetIFRS",
    "pl.research_and_development" => "jpigp_cor:ResearchAndDevelopmentExpenditureRecognizedAsExpenseDuringPeriodIFRS",
    "pl.finance_income" => "jpigp_cor:FinanceIncomeIFRS",
    "pl.finance_costs" => "jpigp_cor:FinanceCostsIFRS",
    "pl.equity_method_profit" => "jpigp_cor:ShareOfProfitLossOfInvestmentsAccountedForUsingEquityMethodIFRS",
    "pl.cost_of_sales"      => "jpigp_cor:CostOfSalesIFRS",
    "pl.gross_profit"       => "jpigp_cor:GrossProfitIFRS",
    "pl.sga"                => "jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS",
    "pl.operating_expenses" => "jpigp_cor:OperatingExpensesIFRS",
    "pl.operating_profit"   => "jpigp_cor:OperatingProfitLossIFRS",
    "pl.profit_before_tax"  => "jpigp_cor:ProfitLossBeforeTaxIFRS",
    "pl.income_tax"         => "jpigp_cor:IncomeTaxExpenseIFRS",
    "pl.profit"             => "jpigp_cor:ProfitLossIFRS",
    "pl.profit_attributable_to_owners" => "jpigp_cor:ProfitLossAttributableToOwnersOfParentIFRS",
    "cf.exchange_effect" => "jpigp_cor:EffectOfExchangeRateChangesOnCashAndCashEquivalentsIFRS",
    "cf.operating" => "jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS",
    "cf.investing" => "jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS", # IFRSはInvesting（JGAAPはInvestment）
    "cf.financing" => "jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS"
  }.freeze
end
