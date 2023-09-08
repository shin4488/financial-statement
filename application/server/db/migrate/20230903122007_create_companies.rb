class CreateCompanies < ActiveRecord::Migration[7.0]
  def change
    create_table :companies, comment: "企業" do |t|
      t.string :edinet_code, limit: 6, null: false, comment: "EDINETコード"
      t.string :stock_code, limit: 5, comment: "証券コード"
      t.string :company_japanese_name, comment: "企業名（日本語）"
      t.string :company_english_name, comment: "企業名（英語）"
      t.timestamps
    end
    add_index :companies, [:edinet_code], unique: true
  end
end
