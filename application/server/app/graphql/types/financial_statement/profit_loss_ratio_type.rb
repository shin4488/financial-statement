# frozen_string_literal: true

module Types
  module FinancialStatement
    class ProfitLossRatioType < Types::BaseObject
      field :net_sales, Float
      field :original_cost, Float
      field :selling_general_expense, Float
      field :operating_income, Float
    end
  end
end
