module Types
  class FinancialMetricSourceType < Types::BaseEnum
    value "CALCULATED", value: "calculated", description: "当サイトの定義による計算値"
    value "DISCLOSED", value: "disclosed", description: "同じ有報・会計基準・連結区分の企業公表値。計算条件は提出書類の注記による"
  end
end
