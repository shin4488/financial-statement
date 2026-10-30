# 列コメントが指す定数を、科目コードと形式の一覧を定義する場所に合わせる。コメントだけを変え、構造とデータは変えない
class UpdateItemCodeAndPresentationFormatComments < ActiveRecord::Migration[7.2]
  def up
    change_column_comment :financial_statement_items, :item_code,
      "正規化科目コード（FinancialStatements::ItemCatalogで管理）"
    change_column_comment :financial_statements, :presentation_format,
      "表示形式（値の一覧はコードの FinancialStatements::Formats::ALL を参照）"
  end

  def down
    change_column_comment :financial_statement_items, :item_code,
      "正規化科目コード（FinancialStatements::ItemCodesレジストリで管理）"
    change_column_comment :financial_statements, :presentation_format,
      "表示形式（値の一覧はコードの Ingestion::FormatRegistry::ALL を参照）"
  end
end
