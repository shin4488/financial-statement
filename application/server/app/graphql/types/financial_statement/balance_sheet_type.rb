# frozen_string_literal: true

module Types
  module FinancialStatement
    class BalanceSheetType < Types::BaseObject
      field :amount, BalanceSheetAmountType
      field :ratio, BalanceSheetRatioType
    end
  end
end
