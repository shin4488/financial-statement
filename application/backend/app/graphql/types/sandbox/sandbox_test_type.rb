# frozen_string_literal: true

module Types
  module Sandbox
    class SandboxTestType < Types::BaseObject
      description "this is Sandbox type to practice GraphQL"
      field :id, ID, null: false
      field :title, String
      field :rating, Integer
    end
  end
end
