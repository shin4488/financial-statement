module Types
  module Chart
    class WaterfallStepType < Types::BaseObject
      field :key, String, null: false
      field :label, String, null: false
      field :amount, Types::MoneyType, null: false, description: "符号付き（増減の向きが情報のため）"
      field :kind, String, null: false, description: '"balance"（残高・0起点） | "flow"（増減・累積位置から描く）'
      field :color_role, String, null: false, description: '"cashIncrease" | "cashDecrease"（Segmentと同じくフロントのパレット対応キー）'
    end
  end
end
