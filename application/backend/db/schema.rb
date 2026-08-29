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

ActiveRecord::Schema[7.2].define(version: 2026_08_29_120001) do
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

  create_table "security_reports", comment: "有価証券報告書", force: :cascade do |t|
    t.bigint "company_id", null: false, comment: "企業id"
    t.date "fiscal_year_start_date", null: false, comment: "会計年度開始日"
    t.date "fiscal_year_end_date", null: false, comment: "会計年度終了日"
    t.date "filing_date", comment: "提出日"
    t.integer "accounting_standard", null: false, comment: "会計基準"
    t.boolean "has_consolidated_financial_statement", default: false, null: false, comment: "連結決算あり"
    t.string "consolidated_inductory_code", comment: "連結業種"
    t.string "non_consolidated_inductory_code", comment: "単体業種"
    t.bigint "consolidated_current_asset", comment: "連結流動資産"
    t.bigint "consolidated_property_plant_and_equipment", comment: "連結有形固定資産"
    t.bigint "consolidated_intangible_asset", comment: "連結無形固定資産"
    t.bigint "consolidated_investment_and_other_asset", comment: "連結投資その他資産"
    t.bigint "consolidated_non_current_asset", comment: "連結固定資産"
    t.bigint "consolidated_asset", comment: "連結資産"
    t.bigint "consolidated_current_liability", comment: "連結流動負債"
    t.bigint "consolidated_non_current_liability", comment: "連結固定負債"
    t.bigint "consolidated_liability", comment: "連結負債"
    t.bigint "consolidated_net_asset", comment: "連結純資産"
    t.bigint "consolidated_net_sales", comment: "連結売上"
    t.bigint "consolidated_cost_of_sales", comment: "連結売上原価"
    t.bigint "consolidated_gross_profit", comment: "連結売上総利益"
    t.bigint "consolidated_selling_general_and_administrative_expense", comment: "連結販売一般管理費"
    t.bigint "consolidated_operating_income", comment: "連結営業利益"
    t.bigint "consolidated_non_operating_income", comment: "連結営業外収益"
    t.bigint "consolidated_non_operating_expense", comment: "連結営業外費用"
    t.bigint "consolidated_ordinary_income", comment: "連結経常利益"
    t.bigint "consolidated_extraordinary_income", comment: "連結特別利益"
    t.bigint "consolidated_extraordinary_loss", comment: "連結特別損失"
    t.bigint "consolidated_income_before_income_tax", comment: "連結税引前当期純利益"
    t.bigint "consolidated_income_tax", comment: "連結法人税等"
    t.bigint "consolidated_profit_loss", comment: "連結当期純利益"
    t.bigint "consolidated_profit_loss_attributable_to_owners_of_parent", comment: "連結親会社株主に帰属する当期純利益"
    t.bigint "consolidated_start_cash_flow_balance", comment: "連結期首残高キャッシュフロー"
    t.bigint "consolidated_operating_activity_cash_flow", comment: "連結営業活動によるキャッシュフロー"
    t.bigint "consolidated_investment_activity_cash_flow", comment: "連結投資活動によるキャッシュフロー"
    t.bigint "consolidated_financing_activity_cash_flow", comment: "連結財務活動によるキャッシュフロー"
    t.bigint "consolidated_end_cash_flow_balance", comment: "連結期末残高キャッシュフロー"
    t.bigint "non_consolidated_current_asset", comment: "単体流動資産"
    t.bigint "non_consolidated_property_plant_and_equipment", comment: "単体有形固定資産"
    t.bigint "non_consolidated_intangible_asset", comment: "単体無形固定資産"
    t.bigint "non_consolidated_investment_and_other_asset", comment: "単体投資その他資産"
    t.bigint "non_consolidated_non_current_asset", comment: "単体固定資産"
    t.bigint "non_consolidated_asset", comment: "単体資産"
    t.bigint "non_consolidated_current_liability", comment: "単体流動負債"
    t.bigint "non_consolidated_non_current_liability", comment: "単体固定負債"
    t.bigint "non_consolidated_liability", comment: "単体負債"
    t.bigint "non_consolidated_net_asset", comment: "単体純資産"
    t.bigint "non_consolidated_net_sales", comment: "単体売上"
    t.bigint "non_consolidated_cost_of_sales", comment: "単体売上原価"
    t.bigint "non_consolidated_gross_profit", comment: "単体売上総利益"
    t.bigint "non_consolidated_selling_general_and_administrative_expense", comment: "単体販売一般管理費"
    t.bigint "non_consolidated_operating_income", comment: "単体営業利益"
    t.bigint "non_consolidated_non_operating_income", comment: "単体営業外収益"
    t.bigint "non_consolidated_non_operating_expense", comment: "単体営業外費用"
    t.bigint "non_consolidated_ordinary_income", comment: "単体経常利益"
    t.bigint "non_consolidated_extraordinary_income", comment: "単体特別利益"
    t.bigint "non_consolidated_extraordinary_loss", comment: "単体特別損失"
    t.bigint "non_consolidated_income_before_income_tax", comment: "単体税引前当期純利益"
    t.bigint "non_consolidated_income_tax", comment: "単体法人税等"
    t.bigint "non_consolidated_profit_loss", comment: "単体当期純利益"
    t.bigint "non_consolidated_profit_loss_attributable_to_owners_of_parent", comment: "単体親会社株主に帰属する当期純利益"
    t.bigint "non_consolidated_start_cash_flow_balance", comment: "単体期首残高キャッシュフロー"
    t.bigint "non_consolidated_operating_activity_cash_flow", comment: "単体営業活動によるキャッシュフロー"
    t.bigint "non_consolidated_investment_activity_cash_flow", comment: "単体投資活動によるキャッシュフロー"
    t.bigint "non_consolidated_financing_activity_cash_flow", comment: "単体財務活動によるキャッシュフロー"
    t.bigint "non_consolidated_end_cash_flow_balance", comment: "単体期末残高キャッシュフロー"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "fiscal_year_start_date", "fiscal_year_end_date"], name: "index_on_security_reports_company_fy_start_end_date", unique: true
  end

  add_foreign_key "financial_statement_items", "financial_statements"
  add_foreign_key "financial_statements", "reports"
  add_foreign_key "reports", "companies"
  add_foreign_key "security_reports", "companies"
end
