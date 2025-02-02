# frozen_string_literal: true

module Types
  module FinancialStatement
    class BalanceSheetRatioType < Types::BaseObject
      field :current_asset, Float
      field :property_plant_and_equipment, Float
      field :intangible_asset, Float
      field :investment_and_other_asset, Float
      field :current_liability, Float
      field :noncurrent_liability, Float
      field :net_asset, Float
    end
  end
end
