class SecurityReport::ReaderRepository
  CONSOLIDATED = "".freeze
  NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

  def initialize(xbrl_file_path)
    @parser = AppFile::XmlParser.new(xbrl_file_path)
    @xbrl_file_path = xbrl_file_path
  end

  def read
    accounting_standard_xml = @parser.extract_text(key: "//jpdei_cor:AccountingStandardsDEI[@contextRef='FilingDateInstant']")
    accounting_standard =
      case accounting_standard_xml
      when "Japan GAAP"
        "japan_gaap"
      when "US GAAP"
        "us_gaap"
      when "IFRS"
        "ifrs"
      else
        ""
      end
    has_consolidated_financial_statement = @parser.extract_text(key: "//jpdei_cor:WhetherConsolidatedFinancialStatementsArePreparedDEI[@contextRef='FilingDateInstant']")
    company_japanese_name =
      @parser.extract_text(key: "//jpcrp_cor:CompanyNameCoverPage[@contextRef='FilingDateInstant']") ||
      @parser.extract_text(key: "//jpdei_cor:FilerNameInJapaneseDEI[@contextRef='FilingDateInstant']")
    company_english_name =
      @parser.extract_text(key: "//jpcrp_cor:CompanyNameInEnglishCoverPage[@contextRef='FilingDateInstant']") ||
      @parser.extract_text(key: "//jpcrp_cor:FilerNameInEnglishDEI[@contextRef='FilingDateInstant']")
    consolidated_reader = SingleSecurityReportsReader.new(CONSOLIDATED, @xbrl_file_path)
    non_consolidated_reader = SingleSecurityReportsReader.new(NON_CONSOLIDATED, @xbrl_file_path)

    {
      edinet_code: @parser.extract_text(key: "//jpdei_cor:EDINETCodeDEI[@contextRef='FilingDateInstant']"),
      stock_code: @parser.extract_text(key: "//jpdei_cor:SecurityCodeDEI[@contextRef='FilingDateInstant']"),
      company_japanese_name: convert_2byte_to_1byte_char(company_japanese_name),
      company_english_name: convert_2byte_to_1byte_char(company_english_name),
      accounting_standard: accounting_standard,
      # 文字列の"true","false"が返されるため、bool値に変換する
      has_consolidated_financial_statement: ActiveRecord::Type::Boolean.new.cast(has_consolidated_financial_statement),
      fiscal_year_start_date: @parser.extract_text(key: "//jpdei_cor:CurrentFiscalYearStartDateDEI[@contextRef='FilingDateInstant']"),
      fiscal_year_end_date: @parser.extract_text(key: "//jpdei_cor:CurrentFiscalYearEndDateDEI[@contextRef='FilingDateInstant']"),
      filing_date: @parser.extract_text(key: "//jpcrp_cor:FilingDateCoverPage[@contextRef='FilingDateInstant']"),
      # TODO:会計基準がIFRSだと、連結財務諸表の数値が0（xbrl上では値なし）となる
      consolidated_inductory_code: @parser.extract_text(key: "//jpdei_cor:IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI[@contextRef='FilingDateInstant']"),
      non_consolidated_inductory_code: @parser.extract_text(key: "//jpdei_cor:IndustryCodeWhenFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI[@contextRef='FilingDateInstant']"),
      consolidated_statement: consolidated_reader.read,
      non_consolidated_statement: non_consolidated_reader.read,
    }
  end

  private
    def convert_2byte_to_1byte_char(text)
      text.tr('０-９ａ-ｚＡ-Ｚ　＆','0-9a-zA-Z &')
    end

  class SingleSecurityReportsReader
    def initialize(consolidation_type, xbrl_file_path)
      @consolidation_type = consolidation_type
      @parser = AppFile::XmlParser.new(xbrl_file_path)
    end

    def read
      {
        # BSデータ
        current_asset: @parser.extract_text(key: "//jppfs_cor:CurrentAssets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        property_plant_and_equipment: @parser.extract_text(key: "//jppfs_cor:PropertyPlantAndEquipment[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        intangible_asset: @parser.extract_text(key: "//jppfs_cor:IntangibleAssets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        investment_and_other_asset: @parser.extract_text(key: "//jppfs_cor:InvestmentsAndOtherAssets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        non_current_asset: @parser.extract_text(key: "//jppfs_cor:NoncurrentAssets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        asset: @parser.extract_text(key: "//jppfs_cor:Assets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        current_liability: @parser.extract_text(key: "//jppfs_cor:CurrentLiabilities[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        non_current_liability: @parser.extract_text(key: "//jppfs_cor:NoncurrentLiabilities[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        liability: @parser.extract_text(key: "//jppfs_cor:Liabilities[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        net_asset: @parser.extract_text(key: "//jppfs_cor:NetAssets[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
        # PLデータ
        # TODO:業種に応じたフォーマットの違いを吸収したい
        # https://www.fsa.go.jp/search/20211109/1f_AccountList.xlsx
        # https://www.fsa.go.jp/search/20130301/01_b2.pdf
        net_sales: (
          @parser.extract_text(key: "//jppfs_cor:NetSales[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 完成業務高
          @parser.extract_text(key: "//jppfs_cor:ContractsCompletedRevOA[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 完成工事高
          @parser.extract_text(key: "//jppfs_cor:NetSalesOfCompletedConstructionContractsCNS[@contextRef='CurrentYearDuration#{@consolidation_type}']")
        ).to_i,
        # 企業によって原価項目の科目名が異なる
        cost_of_sales: (
          @parser.extract_text(key: "//jppfs_cor:CostOfSales[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 商品及び製品売上原価
          @parser.extract_text(key: "//jppfs_cor:CostOfMerchandiseAndFinishedGoodsSoldCOS[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 製品売上原価
          @parser.extract_text(key: "//jppfs_cor:CostOfFinishedGoodsSold[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 商品売上原価
          @parser.extract_text(key: "//jppfs_cor:CostOfGoodsSold[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 完成業務原価
          @parser.extract_text(key: "//jppfs_cor:CostOfCompletedWorkCOSExpOA[@contextRef='CurrentYearDuration#{@consolidation_type}']") ||
          # 完成工事原価
          @parser.extract_text(key: "//jppfs_cor:CostOfSalesOfCompletedConstructionContractsCNS[@contextRef='CurrentYearDuration#{@consolidation_type}']")
        ).to_i,
        gross_profit: @parser.extract_text(key: "//jppfs_cor:GrossProfit[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        selling_general_and_administrative_expense: @parser.extract_text(key: "//jppfs_cor:SellingGeneralAndAdministrativeExpenses[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        operating_income: @parser.extract_text(key: "//jppfs_cor:OperatingIncome[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        non_operating_income: @parser.extract_text(key: "//jppfs_cor:NonOperatingIncome[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        non_operating_expense: @parser.extract_text(key: "//jppfs_cor:NonOperatingExpenses[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        ordinary_income: @parser.extract_text(key: "//jppfs_cor:OrdinaryIncome[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        extraordinary_income: @parser.extract_text(key: "//jppfs_cor:ExtraordinaryIncome[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        extraordinary_loss: @parser.extract_text(key: "//jppfs_cor:ExtraordinaryLoss[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        income_before_income_tax: @parser.extract_text(key: "//jppfs_cor:IncomeBeforeIncomeTaxes[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        income_tax: @parser.extract_text(key: "//jppfs_cor:IncomeTaxes[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        profit_loss: @parser.extract_text(key: "//jppfs_cor:ProfitLoss[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        profit_loss_attributable_to_owners_of_parent: @parser.extract_text(key: "//jppfs_cor:ProfitLossAttributableToOwnersOfParent[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        # CFデータ
        # 「期首 = 1年前の期末」として考える
        start_cash_flow_balance: @parser.extract_text(key: "//jppfs_cor:CashAndCashEquivalents[@contextRef='Prior1YearInstant#{@consolidation_type}']").to_i,
        operating_activity_cash_flow: @parser.extract_text(key: "//jppfs_cor:NetCashProvidedByUsedInOperatingActivities[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        investment_activity_cash_flow: @parser.extract_text(key: "//jppfs_cor:NetCashProvidedByUsedInInvestmentActivities[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        financing_activity_cash_flow: @parser.extract_text(key: "//jppfs_cor:NetCashProvidedByUsedInFinancingActivities[@contextRef='CurrentYearDuration#{@consolidation_type}']").to_i,
        end_cash_flow_balance: @parser.extract_text(key: "//jppfs_cor:CashAndCashEquivalents[@contextRef='CurrentYearInstant#{@consolidation_type}']").to_i,
      }
    end
  end
end
