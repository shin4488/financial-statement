# frozen_string_literal: true

module Types
  module Sandbox
    class SandboxBookmarkType < Types::BaseInputObject
      argument :user_id, String, required: true
      argument :document_id, String, required: true
    end
  end
end