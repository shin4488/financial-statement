module Types
  class CashFlowSignType < Types::BaseEnum
    graphql_name "CashFlowSign"
    value "POSITIVE", value: :positive
    value "NEGATIVE", value: :negative
  end
end
