module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :company_financial_statements, [FinancialStatement::CompanyFinancialStatementType], "Find Company Financial Statement by limit" do
      argument :limit, Integer, validates: { numericality: { greater_than: 0 } }
      argument :offset, Integer, validates: { numericality: { greater_than_or_equal_to: 0 } }
      argument :stock_codes, [String], required: false
      argument :is_positive_operating_activities_cash_flow, Boolean, required: false
      argument :is_positive_investing_activities_cash_flow, Boolean, required: false
      argument :is_positive_financing_activities_cash_flow, Boolean, required: false
    end
    def company_financial_statements(
      limit: 100,
      offset: 0,
      stock_codes: [],
      is_positive_operating_activities_cash_flow: nil,
      is_positive_investing_activities_cash_flow: nil,
      is_positive_financing_activities_cash_flow: nil
    )
      condition = {
        stock_codes: stock_codes || [],
        is_positive_operating_activities_cash_flow: is_positive_operating_activities_cash_flow,
        is_positive_investing_activities_cash_flow: is_positive_investing_activities_cash_flow,
        is_positive_financing_activities_cash_flow: is_positive_financing_activities_cash_flow,
      }
      SecurityReport::FetcherService.fetch_security_reports(limit:, offset:, condition:)
    end
  end
end
