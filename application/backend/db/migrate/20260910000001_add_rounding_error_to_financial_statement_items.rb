class AddRoundingErrorToFinancialStatementItems < ActiveRecord::Migration[7.2]
  def change
    add_column :financial_statement_items, :rounding_error, :decimal,
               comment: "XBRL開示精度に基づく丸め誤差上限（円）。NULLは精度不明"
  end
end
