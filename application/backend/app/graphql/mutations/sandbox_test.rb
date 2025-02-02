module Mutations
  class SandboxTest < Mutations::BaseMutation
    argument :attributes, Types::Sandbox::SandboxBookmarkType
    field :sandbox_testaa, Types::Sandbox::SandboxTestType, null: false

    def resolve(attributes:)
      {
        :sandbox_testaa => {
          :id => attributes[:user_id],
          :title => attributes[:document_id],
        }
      }
    end
  end
end
