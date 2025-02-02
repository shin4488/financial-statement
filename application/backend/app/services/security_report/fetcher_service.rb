class SecurityReport::FetcherService
  RATIO_TRUNCATED_POSITION = 3

  class << self
    def fetch_security_reports(limit:, offset:, condition:)
      # 証券コードは内部的には5桁で保存しているが、通常4桁で扱われるため0パディングする
      stock_codes = condition[:stock_codes].map { |code| "#{code}0" }
      cash_flow_condition = {
        operating_activities_cash_flow_sign: condition[:operating_activities_cash_flow_sign],
        investing_activities_cash_flow_sign: condition[:investing_activities_cash_flow_sign],
        financing_activities_cash_flow_sign: condition[:financing_activities_cash_flow_sign],
      }.compact.presence
      reports =
        if cash_flow_condition.nil?
          SecurityReport.fetch_company_security_reports(limit:, offset:, stock_codes:)
        else
          SecurityReport.fetch_company_security_reports_with_cash_flow_condition(limit:, offset:, stock_codes:, cash_flow_condition:)
        end

      reports.map do |security_report|
        has_consolidation = security_report.has_consolidated_financial_statement

        # 投資判断的には連結財務諸表が大切なはずのため、連結財務諸表があれば連結財務諸表のみを返す
        # 貸借対照表
        balance_sheet =
        if has_consolidation
          {
            current_asset: security_report.consolidated_current_asset,
            property_plant_and_equipment: security_report.consolidated_property_plant_and_equipment,
            intangible_asset: security_report.consolidated_intangible_asset,
            investment_and_other_asset: security_report.consolidated_investment_and_other_asset,
            current_liability: security_report.consolidated_current_liability,
            noncurrent_liability: security_report.consolidated_non_current_liability,
            net_asset: security_report.consolidated_net_asset,
          }
        else
          {
            current_asset: security_report.non_consolidated_current_asset,
            property_plant_and_equipment: security_report.non_consolidated_property_plant_and_equipment,
            intangible_asset: security_report.non_consolidated_intangible_asset,
            investment_and_other_asset: security_report.non_consolidated_investment_and_other_asset,
            current_liability: security_report.non_consolidated_current_liability,
            noncurrent_liability: security_report.non_consolidated_non_current_liability,
            net_asset: security_report.non_consolidated_net_asset,
          }
        end
        # 資産
        current_asset = balance_sheet[:current_asset].to_s.to_s.to_d
        property_plant_and_equipment = balance_sheet[:property_plant_and_equipment].to_s.to_d
        intangible_asset = balance_sheet[:intangible_asset].to_s.to_d
        investment_and_other_asset = balance_sheet[:investment_and_other_asset].to_s.to_d
        total_asset_amount = current_asset + property_plant_and_equipment + intangible_asset + investment_and_other_asset
        current_asset_ratio = (current_asset / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)
        property_plant_and_equipment_ratio = (property_plant_and_equipment / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)
        intangible_asset_ratio = (intangible_asset / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)
        investment_and_other_asset_ratio = 1 - (current_asset_ratio + property_plant_and_equipment_ratio + intangible_asset_ratio)
        # 負債
        current_liability = balance_sheet[:current_liability].to_s.to_d
        noncurrent_liability = balance_sheet[:noncurrent_liability].to_s.to_d
        net_asset = balance_sheet[:net_asset].to_s.to_d
        current_liability_ratio = (current_liability / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)
        noncurrent_liability_ratio = (noncurrent_liability / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)
        # 債務超過の時は総資産と比較した比率を算出する
        net_asset_ratio = net_asset > 0 ? 1 - (current_liability_ratio + noncurrent_liability_ratio) : (net_asset / total_asset_amount).truncate(RATIO_TRUNCATED_POSITION)

        # 損益計算書
        profit_loss =
        if has_consolidation
          {
            net_sales: security_report.consolidated_net_sales,
            original_cost: security_report.consolidated_cost_of_sales,
            selling_general_expense: security_report.consolidated_selling_general_and_administrative_expense,
            operating_income: security_report.consolidated_operating_income,
          }
        else
          {
            net_sales: security_report.non_consolidated_net_sales,
            original_cost: security_report.non_consolidated_cost_of_sales,
            selling_general_expense: security_report.non_consolidated_selling_general_and_administrative_expense,
            operating_income: security_report.non_consolidated_operating_income,
          }
        end
        net_sales = profit_loss[:net_sales].to_s.to_d
        original_cost = profit_loss[:original_cost].to_s.to_d
        selling_general_expense = profit_loss[:selling_general_expense].to_s.to_d
        operating_income = profit_loss[:operating_income].to_s.to_d
        original_cost_ratio = (original_cost / net_sales).truncate(RATIO_TRUNCATED_POSITION)
        selling_general_expense_ratio = (selling_general_expense / net_sales).truncate(RATIO_TRUNCATED_POSITION)
        operating_income_ratio = operating_income > 0 ? 1 - (original_cost_ratio + selling_general_expense_ratio) : (operating_income / net_sales).truncate(RATIO_TRUNCATED_POSITION)

        # キャッシュフロー計算書
        cash_flow =
        if has_consolidation
          {
            starting_cash: security_report.consolidated_start_cash_flow_balance,
            operating_activities_cash_flow: security_report.consolidated_operating_activity_cash_flow,
            investing_activities_cash_flow: security_report.consolidated_investment_activity_cash_flow,
            financing_activities_cash_flow: security_report.consolidated_financing_activity_cash_flow,
            ending_cash: security_report.consolidated_end_cash_flow_balance,
          }
        else
          {
            starting_cash: security_report.non_consolidated_start_cash_flow_balance,
            operating_activities_cash_flow: security_report.non_consolidated_operating_activity_cash_flow,
            investing_activities_cash_flow: security_report.non_consolidated_investment_activity_cash_flow,
            financing_activities_cash_flow: security_report.non_consolidated_financing_activity_cash_flow,
            ending_cash: security_report.non_consolidated_end_cash_flow_balance,
          }
        end

        {
          id: security_report.id,
          fiscal_year_start_date: security_report.fiscal_year_start_date.to_s,
          fiscal_year_end_date: security_report.fiscal_year_end_date.to_s,
          filing_date: security_report.filing_date,
          stock_code: security_report.company.stock_code,
          company_japanese_name: security_report.company.company_japanese_name,
          has_consolidated_financial_statement: security_report.has_consolidated_financial_statement,
          consolidated_inductory_code: security_report.consolidated_inductory_code,
          non_consolidated_inductory_code: security_report.non_consolidated_inductory_code,
          balance_sheet: {
            amount: balance_sheet,
            ratio: {
              current_asset: current_asset_ratio * 100,
              property_plant_and_equipment: property_plant_and_equipment_ratio * 100,
              intangible_asset: intangible_asset_ratio * 100,
              investment_and_other_asset: investment_and_other_asset_ratio * 100,
              current_liability: current_liability_ratio * 100,
              noncurrent_liability: noncurrent_liability_ratio * 100,
              net_asset: net_asset_ratio * 100,
            }
          },
          profit_loss: {
            amount: profit_loss,
            ratio: {
              # 割合は売上比で考えるため、売上は100固定
              net_sales: 100,
              original_cost: original_cost_ratio * 100,
              selling_general_expense: selling_general_expense_ratio * 100,
              operating_income: operating_income_ratio * 100,
            }
          },
          cash_flow: cash_flow,
        }
      end
    end
  end
end
