# IFRSの損益計算書（要約の売上を除く）。損益計算書のタグは財政状態計算書の様式（511000・512000）によらない
Ingestion::Mappings::IfrsProfitLoss = Ingestion::Mappings::Section.define do
  # 収益: 標準3系列 → 最後に経営指標サマリ。
  # サマリを入れる理由: 本表の収益が企業拡張タグのみの企業があり、標準タグでは取れない。
  # サマリの値は本表と一致する。
  # サマリを最後に置く理由: 本表タグの方が一次情報であり、サマリは表示単位変更などの
  # リスクが理論上あるため、あくまでフォールバック。
  # サマリにもない会社は、原本で収益の合計と確かめた企業拡張タグの要素名で探す（日本基準と同じ考え方）。
  # 標準タグの収益に「その他の収益」などを含めて収益合計とし、営業収益を企業拡張タグに付ける会社もあるため、
  # その要素名も並べ、要約の売上と照合して差し替える候補にする
  item "pl.revenue", %w[
    jpigp_cor:RevenueIFRS
    jpigp_cor:Revenue2IFRS
    jpigp_cor:NetSalesIFRS
    jpcrp_cor:RevenueIFRSSummaryOfBusinessResults
    filer_ext:OperatingRevenuesIFRS
    filer_ext:OperatingRevenueIFRS
    filer_ext:TotalNetRevenuesIFRS
    filer_ext:OperatingRevenueRevenue2IFRS
    filer_ext:OperatingRevenueRevenueIFRS
  ]
  item "pl.other_operating_income", [ "jpigp_cor:OtherOperatingIncomeIFRS", "jpigp_cor:OtherIncomeIFRS" ]
  item "pl.other_operating_expenses", [ "jpigp_cor:OtherOperatingExpensesIFRS", "jpigp_cor:OtherExpensesIFRS" ]
  item "pl.other_income_expenses_net", "jpigp_cor:OtherIncomeExpensesNetIFRS"
  item "pl.research_and_development", "jpigp_cor:ResearchAndDevelopmentExpenditureRecognizedAsExpenseDuringPeriodIFRS"
  item "pl.general_and_administrative_expenses", "jpigp_cor:GeneralAndAdministrativeExpensesIFRS"
  item "pl.finance_income", "jpigp_cor:FinanceIncomeIFRS"
  item "pl.finance_costs", "jpigp_cor:FinanceCostsIFRS"
  item "pl.equity_method_profit", "jpigp_cor:ShareOfProfitLossOfInvestmentsAccountedForUsingEquityMethodIFRS"
  item "pl.cost_of_sales", "jpigp_cor:CostOfSalesIFRS"
  item "pl.gross_profit", "jpigp_cor:GrossProfitIFRS"
  item "pl.sga", "jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS"
  item "pl.operating_expenses", "jpigp_cor:OperatingExpensesIFRS"
  item "pl.operating_profit", "jpigp_cor:OperatingProfitLossIFRS"
  item "pl.profit_before_tax", "jpigp_cor:ProfitLossBeforeTaxIFRS"
  item "pl.income_tax", "jpigp_cor:IncomeTaxExpenseIFRS"
  item "pl.profit", "jpigp_cor:ProfitLossIFRS"
  item "pl.profit_attributable_to_owners", "jpigp_cor:ProfitLossAttributableToOwnersOfParentIFRS"
end
