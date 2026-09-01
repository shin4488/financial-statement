# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_09_01_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "companies", comment: "企業", force: :cascade do |t|
    t.string "edinet_code", limit: 6, null: false, comment: "EDINETコード"
    t.string "stock_code", limit: 5, comment: "証券コード"
    t.string "company_japanese_name", comment: "企業名（日本語）"
    t.string "company_english_name", comment: "企業名（英語）"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edinet_code"], name: "index_companies_on_edinet_code", unique: true
  end

  create_table "financial_statement_items", comment: "財務諸表科目（正規化・縦持ち）", force: :cascade do |t|
    t.bigint "financial_statement_id", null: false
    t.string "item_code", null: false, comment: "正規化科目コード（FinancialStatements::ItemCodesレジストリで管理）"
    t.bigint "amount", null: false, comment: "金額（円）。取得できなかった科目は行を作らない"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["financial_statement_id", "item_code"], name: "idx_items_fs_code", unique: true
    t.index ["item_code", "amount"], name: "idx_items_code_amount"
  end

  create_table "financial_statements", comment: "財務諸表（連結/単体 * 1有報）", force: :cascade do |t|
    t.bigint "report_id", null: false, comment: "有報id"
    t.integer "consolidation_type", null: false, comment: "0:consolidated 1:non_consolidated"
    t.integer "accounting_standard", null: false, comment: "この財務諸表の会計基準（有報全体と異なり得る）"
    t.string "presentation_format", null: false, comment: "表示形式（値の一覧はコードの Ingestion::FormatRegistry::ALL を参照）"
    t.boolean "is_primary", default: false, null: false, comment: "表示・検索の主対象（連結があれば連結）"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id", "consolidation_type"], name: "idx_fs_report_consolidation", unique: true
    t.index ["report_id"], name: "index_financial_statements_on_report_id"
    t.index ["report_id"], name: "index_financial_statements_primary_unique_per_report", unique: true, where: "is_primary"
  end

  create_table "reports", comment: "有価証券報告書", force: :cascade do |t|
    t.bigint "company_id", null: false, comment: "企業id"
    t.string "edinet_document_id", limit: 8, null: false, comment: "EDINET書類管理番号"
    t.date "fiscal_year_start_date", null: false, comment: "会計年度開始日"
    t.date "fiscal_year_end_date", null: false, comment: "会計年度終了日"
    t.date "filing_date", comment: "提出日"
    t.string "company_name_ja", comment: "提出時点の企業名（日本語）"
    t.string "company_name_en", comment: "提出時点の企業名（英語）"
    t.integer "accounting_standard", null: false, comment: "会計基準(DEI) 0:japan_gaap 1:us_gaap 2:ifrs"
    t.boolean "has_consolidated_statement", default: false, null: false, comment: "連結財務諸表あり"
    t.string "consolidated_industry_code", comment: "連結業種コード(DEI)"
    t.string "non_consolidated_industry_code", comment: "単体業種コード(DEI)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "fiscal_year_start_date", "fiscal_year_end_date"], name: "idx_reports_company_fiscal_year", unique: true
    t.index ["company_id"], name: "index_reports_on_company_id"
    t.index ["filing_date", "fiscal_year_end_date", "updated_at"], name: "idx_reports_filing_order", order: { filing_date: "DESC NULLS LAST", fiscal_year_end_date: :desc, updated_at: :desc }
    t.index ["filing_date"], name: "index_reports_on_filing_date"
  end

  add_foreign_key "financial_statement_items", "financial_statements"
  add_foreign_key "financial_statements", "reports"
  add_foreign_key "reports", "companies"
end
