module Types
  module Chart
    class SegmentType < Types::BaseObject
      field :key, String, null: false
      field :label, String, null: false
      field :amount, Types::MoneyType, null: false, description: "描画高さ（常に0以上）"
      field :signed_amount, Types::MoneyType, null: false, description: "実値（ツールチップ用。損失は負）"
      field :ratio, Float, null: true, description: "%（spacer等の非表示セグメントはnull）"
      field :color_role, String, null: false
      field :tooltip_label, String, null: true, description: "ツールチップでの表示名（nullならlabelを表示）"
    end
  end
end
