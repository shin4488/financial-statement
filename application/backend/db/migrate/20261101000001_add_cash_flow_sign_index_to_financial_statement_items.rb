class AddCashFlowSignIndexToFinancialStatementItems < ActiveRecord::Migration[8.1]
  # 一覧のCFの符号の絞り込み（Disclosure::SearchQuery#apply_cf_signs）は、CFの3科目の行を財務諸表idごとに集める。
  # 既存の索引（item_code, amount）には財務諸表idがないため、一致した行ごとに表本体を読む。
  # CFの行は、財務諸表ごとにまとめて入れたほかの科目の間に散らばっているため、表のほぼ全体を読むことになる。
  # 財務諸表idを含め、CFの3科目だけを持つ部分索引にして、表本体を読まずに索引だけで集められるようにする
  disable_ddl_transaction!

  def up
    add_index :financial_statement_items, [ :item_code, :amount, :financial_statement_id ],
              where: "item_code IN ('cf.operating', 'cf.investing', 'cf.financing')",
              name: "idx_items_cf_sign", algorithm: :concurrently
    # 索引だけで読むには、表の可視性マップ（全行が見えるページの記録）が要る。
    # PostgreSQL 12の自動VACUUMは行の追加だけでは動かないため、ここで作る。
    # この後に追加した行は、次のVACUUMまで表本体も読む（1年分の追加でも、読む量は索引がないときの約7分の1）
    execute "VACUUM (ANALYZE) financial_statement_items"
  end

  def down
    remove_index :financial_statement_items, name: "idx_items_cf_sign", algorithm: :concurrently
  end
end
