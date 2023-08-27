module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :sandbox_tests, [Sandbox::SandboxTestType], "Find SandboxTest by id" do
      argument :id, ID
    end
    def sandbox_tests(id:)
      results = []
      10.times do |i|
        results.push({
          :id => id,
          :title => "タイトル #{i}",
          :rating => 1000 * i,
          :sub_sandboxes => [
            {
              :id => 0,
              :note => "メモ #{i}"
            }
          ]
        })
      end

      results
    end

    field :company_financial_statements, [FinancialStatement::CompanyFinancialStatementType], "Find Company Financial Statement by limit" do
      argument :limit, Integer
    end
    def company_financial_statements(limit:)
      puts "company_financial_statement_type limit: #{limit}"
      financial_statements = [
        {
          id: 0,
          fiscal_year_start_date: '2021-07-01',
          fiscal_year_end_date: '2022-06-30',
          company_name: 'オルバヘルスケアホールディングス株式会社',
          balance_sheet: {
            current_asset: 32908208000,
            property_plant_and_equipment: 4304433000,
            intangible_asset: 814974000,
            investment_and_other_asset: 1941055000,
            current_liability: 28866106000,
            noncurrent_liability: 2009258000,
            net_asset: 9093306000,
          },
          profit_loss: {
            net_sales: 107959426000,
            original_cost: 95455447000,
            selling_general_expense: 10430832000,
            operating_income: 2073146000,
          },
          cash_flow: {
            starting_cash: 2110675000,
            operating_activities_cash_flow: 2420642000,
            investing_activities_cash_flow: -211806000,
            financing_activities_cash_flow: -1169906000,
            ending_cash: 3149605000,
          },
        },
        {
          id: 1,
          fiscal_year_start_date: '2021-07-01',
          fiscal_year_end_date: '2022-06-30',
          company_name: '株式会社ＡｍｉｄＡホールディングス',
          balance_sheet: {
            current_asset: 2182649000,
            property_plant_and_equipment: 312374000,
            intangible_asset: 56027000,
            investment_and_other_asset: 34293000,
            current_liability: 332198000,
            noncurrent_liability: 76480000,
            net_asset: 2176666000,
          },
          profit_loss: {
            net_sales: 3055422000,
            original_cost: 1421813000,
            selling_general_expense: 1195403000,
            operating_income: 438206000,
          },
          cash_flow: {
            starting_cash: 1567892000,
            operating_activities_cash_flow: 301753000,
            investing_activities_cash_flow: -34107000,
            financing_activities_cash_flow: -77705000,
            ending_cash: 1757833000,
          },
        }
      ]
      financial_statements
    end
  end
end
