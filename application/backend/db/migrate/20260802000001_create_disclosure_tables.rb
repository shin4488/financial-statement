# companies テーブルはここでは作らない: 企業マスタを二重に持たないよう、
# SecurityReport 系機能と同じ companies を Disclosure::Company からも共用するため
class CreateDisclosureTables < ActiveRecord::Migration[7.0]
  def change
    create_table :reports, comment: "有価証券報告書" do |t|
      t.references :company, null: false, foreign_key: true, comment: "企業id"
      t.string :edinet_document_id, limit: 8, null: false, comment: "EDINET書類管理番号"
      t.date :fiscal_year_start_date, null: false, comment: "会計年度開始日"
      t.date :fiscal_year_end_date, null: false, comment: "会計年度終了日"
      t.date :filing_date, comment: "提出日"
      # 企業名をcompanies（最新名のマスタ）と別にここにも持つ理由:
      # 社名変更があった場合、各年度の有報は提出当時の企業名で表示したいため
      t.string :company_name_ja, comment: "提出時点の企業名（日本語）"
      t.string :company_name_en, comment: "提出時点の企業名（英語）"
      t.integer :accounting_standard, null: false, comment: "会計基準(DEI) 0:japan_gaap 1:us_gaap 2:ifrs"
      t.boolean :has_consolidated_statement, null: false, default: false, comment: "連結財務諸表あり"
      t.string :consolidated_industry_code, comment: "連結業種コード(DEI)"
      t.string :non_consolidated_industry_code, comment: "単体業種コード(DEI)"
      t.timestamps
      t.index [:company_id, :fiscal_year_start_date, :fiscal_year_end_date],
              unique: true, name: "idx_reports_company_fiscal_year"
      t.index :filing_date
    end

    create_table :financial_statements, comment: "財務諸表（連結/単体 * 1有報）" do |t|
      t.references :report, null: false, foreign_key: true, comment: "有報id"
      t.integer :consolidation_type, null: false, comment: "0:consolidated 1:non_consolidated"
      t.integer :accounting_standard, null: false, comment: "この財務諸表の会計基準（有報全体と異なり得る）"
      t.string :presentation_format, null: false, comment: "表示形式 jgaap_general/jgaap_bank/ifrs_classified/ifrs_liquidity/unsupported"
      t.boolean :is_primary, null: false, default: false, comment: "表示・検索の主対象（連結があれば連結）"
      t.timestamps
      t.index [:report_id, :consolidation_type], unique: true, name: "idx_fs_report_consolidation"
      t.index :is_primary
    end

    create_table :financial_statement_items, comment: "財務諸表科目（正規化・縦持ち）" do |t|
      t.references :financial_statement, null: false, foreign_key: true, index: false
      t.string :item_code, null: false, comment: "正規化科目コード（FinancialStatements::ItemCodesレジストリで管理）"
      t.bigint :amount, null: false, comment: "金額（円）。取得できなかった科目は行を作らない"
      t.timestamps
      t.index [:financial_statement_id, :item_code], unique: true, name: "idx_items_fs_code"
      t.index [:item_code, :amount], name: "idx_items_code_amount" # CF符号フィルタ用
    end
  end
end
