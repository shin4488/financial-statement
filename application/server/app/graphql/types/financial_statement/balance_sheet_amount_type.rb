# frozen_string_literal: true

module Types
  module FinancialStatement
    class BalanceSheetAmountType < Types::BaseObject
      field :current_asset, GraphQL::Types::BigInt
      field :property_plant_and_equipment, GraphQL::Types::BigInt
      field :intangible_asset, GraphQL::Types::BigInt
      field :investment_and_other_asset, GraphQL::Types::BigInt
      field :current_liability, GraphQL::Types::BigInt
      field :noncurrent_liability, GraphQL::Types::BigInt
      field :net_asset, GraphQL::Types::BigInt
    end
  end
end
