# 一覧の並び順（提出日降順）そのままの複合インデックス。
# 無フィルタの一覧取得をソートなしの先頭walk（LIMIT分だけの走査）にするため、
# 列の並びと方向・NULLS LASTを検索クエリのORDER BYと完全一致させる
class AddFilingOrderIndexToReports < ActiveRecord::Migration[7.2]
  def change
    add_index :reports, [ :filing_date, :fiscal_year_end_date, :updated_at ],
              name: "idx_reports_filing_order",
              order: { filing_date: "DESC NULLS LAST", fiscal_year_end_date: :desc, updated_at: :desc }
  end
end
