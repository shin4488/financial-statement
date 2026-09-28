module Types
  module Chart
    class FreeCashFlowTrendType < Types::BaseObject
      field :renderable, Boolean, null: false
      field :note, String, null: true
      field :points, [ Types::Chart::FreeCashFlowPointType ], null: false
    end
  end
end
