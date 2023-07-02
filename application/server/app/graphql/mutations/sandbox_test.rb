module Mutations
  class SandboxTest < Mutations::BaseMutation
    argument :attributes, Types::BookmarkType
    field :sandbox_testaa, Types::SandboxTestType, null: false

    def resolve(attributes:)
      {
        :sandbox_testaa => {
            :id => attributes[:user_id],
            :title => attributes[:document_id],
            :rating => attributes[:test_arg]
        }
      }
    end
  end
end
