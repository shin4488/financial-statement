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
      argument :operating_activities_cash_flow_sign, FinancialStatement::NumberSignType, required: false
      argument :investing_activities_cash_flow_sign, FinancialStatement::NumberSignType, required: false
      argument :financing_activities_cash_flow_sign, FinancialStatement::NumberSignType, required: false
    end
    def company_financial_statements(
      limit: 100,
      offset: 0,
      stock_codes: [],
      operating_activities_cash_flow_sign: nil,
      investing_activities_cash_flow_sign: nil,
      financing_activities_cash_flow_sign: nil
    )
      condition = {
        stock_codes: stock_codes || [],
        operating_activities_cash_flow_sign: operating_activities_cash_flow_sign,
        investing_activities_cash_flow_sign: investing_activities_cash_flow_sign,
        financing_activities_cash_flow_sign: financing_activities_cash_flow_sign,
      }
      SecurityReport::FetcherService.fetch_security_reports(limit:, offset:, condition:)
    end
  end
end
