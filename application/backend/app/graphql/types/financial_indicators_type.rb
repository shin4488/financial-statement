module Types
  class FinancialIndicatorsType < Types::BaseObject
    field :roe, Types::FinancialMetricType, null: false
    field :roa, Types::FinancialMetricType, null: false
    field :net_profit_margin, Types::FinancialMetricType, null: false
    field :asset_turnover, Types::FinancialMetricType, null: false
    field :financial_leverage, Types::FinancialMetricType, null: false
  end
end
