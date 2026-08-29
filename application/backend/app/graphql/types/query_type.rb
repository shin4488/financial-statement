module Types
  class QueryType < Types::BaseObject
    field :financial_reports, resolver: Resolvers::FinancialReports
  end
end
