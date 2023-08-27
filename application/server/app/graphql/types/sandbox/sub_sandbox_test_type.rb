# frozen_string_literal: true

module Types
  module Sandbox
    class SubSandboxTestType < Types::BaseObject
      field :id, ID, null: false
      field :note, String
    end
  end
end