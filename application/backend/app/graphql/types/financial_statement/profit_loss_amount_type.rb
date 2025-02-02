# frozen_string_literal: true

module Types
  module FinancialStatement
    class ProfitLossAmountType < Types::BaseObject
      field :net_sales, GraphQL::Types::BigInt
      field :original_cost, GraphQL::Types::BigInt
      field :selling_general_expense, GraphQL::Types::BigInt
      field :operating_income, GraphQL::Types::BigInt
    end
  end
end
