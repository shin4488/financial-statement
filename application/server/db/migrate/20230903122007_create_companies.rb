class CreateCompanies < ActiveRecord::Migration[7.0]
  def change
    create_table :companies, comment: "企業" do |t|
      t.string :editnet_code, limit: 6, null: false, comment: "EDINETコード"
      t.integer :stock_code, limit: 2, comment: "証券コード"
      t.string :company_japanese_name, comment: "企業名（日本語）"
      t.string :company_english_name, comment: "企業名（英語）"
      t.string :consolidated_inductory_code, comment: "連結業種"
      t.string :separate_inductory_code, comment: "単体業種"
      t.timestamps
    end
    add_index :companies, [:editnet_code], unique: true
  end
end
