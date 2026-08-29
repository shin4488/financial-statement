class AddPrimaryUniqueIndexToFinancialStatements < ActiveRecord::Migration[7.2]
  # 「1有報にprimaryは1つ」は一覧検索のJOINの前提（崩れると同じ有報が2回表示される）だが、
  # これまでアプリの取込ロジックだけで担保していたため、DBの部分ユニークインデックスで保証する
  def up
    # 万一すでに複数primaryの有報があるとインデックス作成が失敗するため、先に修復する。
    # 残す側の規則は取込（ReportIngester#primary?）と同じ:
    # 連結を作成する企業（has_consolidated_statement）は連結(0)、作成しない企業は単体(1)
    execute <<~SQL
      UPDATE financial_statements
      SET is_primary = FALSE
      FROM reports
      WHERE financial_statements.report_id = reports.id
        AND financial_statements.is_primary
        AND financial_statements.consolidation_type
              <> (CASE WHEN reports.has_consolidated_statement THEN 0 ELSE 1 END)
        AND EXISTS (
          SELECT 1 FROM financial_statements dup
          WHERE dup.report_id = financial_statements.report_id
            AND dup.is_primary
            AND dup.id <> financial_statements.id
        )
    SQL
    add_index :financial_statements, :report_id, unique: true, where: "is_primary",
              name: "index_financial_statements_primary_unique_per_report"
    # is_primary単独のインデックスは真偽2値で絞り込み効果がなく、
    # primaryの検索は上の部分インデックス（report_id付き）が担うため外す
    remove_index :financial_statements, name: "index_financial_statements_on_is_primary"
  end

  def down
    add_index :financial_statements, :is_primary, name: "index_financial_statements_on_is_primary"
    remove_index :financial_statements, name: "index_financial_statements_primary_unique_per_report"
  end
end
