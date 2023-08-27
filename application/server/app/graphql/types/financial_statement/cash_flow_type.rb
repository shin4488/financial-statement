# frozen_string_literal: true

module Types
  module FinancialStatement
    class CashFlowType < Types::BaseObject
      field :starting_cash, GraphQL::Types::BigInt
      field :operating_activities_cash_flow, GraphQL::Types::BigInt
      field :investing_activities_cash_flow, GraphQL::Types::BigInt
      field :financing_activities_cash_flow, GraphQL::Types::BigInt
      field :ending_cash, GraphQL::Types::BigInt
    end
  end
end
