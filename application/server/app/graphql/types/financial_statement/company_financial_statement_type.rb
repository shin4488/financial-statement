# frozen_string_literal: true

module Types
  module FinancialStatement
    class CompanyFinancialStatementType < Types::BaseObject
      field :id, ID, null: false
      field :fiscal_year_start_date, String
      field :fiscal_year_end_date, String
      field :company_japanese_name, String
      field :balance_sheet, Types::FinancialStatement::BalanceSheetType
      field :profit_loss, Types::FinancialStatement::ProfitLossType
      field :cash_flow, Types::FinancialStatement::CashFlowType
    end
  end
end
