# frozen_string_literal: true

module Types
  module FinancialStatement
    class ProfitLossType < Types::BaseObject
      field :amount, ProfitLossAmountType
      field :ratio, ProfitLossRatioType
    end
  end
end
