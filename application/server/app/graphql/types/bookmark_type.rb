# frozen_string_literal: true

module Types
  class BookmarkType < Types::BaseInputObject
    argument :user_id, String, required: true
    argument :document_id, String, required: true
    argument :test_arg, Integer 
  end
end