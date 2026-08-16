module Types
  module Chart
    class StackChartType < Types::BaseObject
      field :renderable, Boolean, null: false
      field :note, String, null: true, description: "renderable=false のとき表示する説明文"
      field :bars, [ Types::Chart::StackBarType ], null: false
    end
  end
end
