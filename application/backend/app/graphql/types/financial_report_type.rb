module Types
  # 有報1通分の財務3表チャート。フロントは科目・会計基準・形式を解釈せず、
  # チャート構造（bars/segments・steps）をそのまま描画する契約
  class FinancialReportType < Types::BaseObject
    field :id, ID, null: false
    field :stock_code, String, null: true, description: "4桁（EDINETの5桁から末尾0を落として返す）"
    field :company_name, String, null: true
    field :fiscal_year_start_date, String, null: false
    field :fiscal_year_end_date, String, null: false
    field :filing_date, String, null: true
    field :accounting_standard, String, null: false, description: "表示中の財務諸表の基準（バッジ表示用。描画分岐に使わないこと）"
    field :consolidation_type, String, null: false, description: '"consolidated" | "non_consolidated"'
    field :presentation_format, String, null: false
    field :balance_sheet, Types::Chart::StackChartType, null: false
    field :profit_loss, Types::Chart::StackChartType, null: false
    field :cash_flow, Types::Chart::WaterfallChartType, null: false
  end
end
