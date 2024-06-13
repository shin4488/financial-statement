# frozen_string_literal: true

module Types
  module FinancialStatement
    class NumberSignType < Types::BaseEnum
      value "POSITIVE", value: :positive
      value "NEGATIVE", value: :negative
    end
  end
end
