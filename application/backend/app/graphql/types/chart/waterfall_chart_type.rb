module Types
  module Chart
    class WaterfallChartType < Types::BaseObject
      field :renderable, Boolean, null: false
      field :note, String, null: true
      field :steps, [ Types::Chart::WaterfallStepType ], null: false
    end
  end
end
