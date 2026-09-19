class AddDisclosedRoeToFinancialStatements < ActiveRecord::Migration[7.2]
  def change
    add_column :financial_statements, :disclosed_roe, :decimal,
               comment: "企業公表ROE（倍率、0.16 = 16%）。計算値とは別に保持"
    add_column :financial_statements, :disclosed_roe_checked_at, :datetime,
               comment: "公表ROEの抽出確認日時。値なしと未移行を区別"
  end
end
