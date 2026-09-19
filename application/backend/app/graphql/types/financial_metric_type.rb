module Types
  class FinancialMetricType < Types::BaseObject
    field :value, Float, null: true, description: "倍率（0.16 = 16%）。表示直前まで丸めない"
    field :status, Types::FinancialMetricStatusType, null: false
  end
end
