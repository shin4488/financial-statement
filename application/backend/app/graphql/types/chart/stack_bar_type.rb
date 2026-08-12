module Types
  module Chart
    class StackBarType < Types::BaseObject
      field :label, String, null: false
      field :segments, [ Types::Chart::SegmentType ], null: false
    end
  end
end
