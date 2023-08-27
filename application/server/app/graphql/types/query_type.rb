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
  end
end
