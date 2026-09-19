module Types
  class FinancialMetricStatusType < Types::BaseEnum
    value "AVAILABLE", value: "available", description: "算出済み"
    value "MISSING_DATA", value: "missing_data", description: "必要な金額・期首値がない"
    value "NOT_CALCULABLE", value: "not_calculable", description: "分母が0以下などの理由で算出できない"
  end
end
