module Types
  class FinancialMetricType < Types::BaseObject
    field :value, Float, null: true, description: "倍率（0.16 = 16%）。表示直前まで丸めない"
    field :source, Types::FinancialMetricSourceType, null: true, description: "値の出所。欠損・算出不可ではnull"
    field :status, Types::FinancialMetricStatusType, null: false
  end
end
