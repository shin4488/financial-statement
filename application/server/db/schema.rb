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

ActiveRecord::Schema[7.0].define(version: 2023_09_04_131246) do
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

  add_foreign_key "security_reports", "companies"
end
