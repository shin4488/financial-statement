FactoryBot.define do
  factory :disclosure_company, class: "Disclosure::Company" do
    sequence(:edinet_code) { |n| format("E%05d", n) }
    stock_code { "45020" } # EDINETの規約どおり5桁で持つ（4桁化はAPI境界の責務）
    name_ja { "テスト株式会社" }
  end

  factory :disclosure_report, class: "Disclosure::Report" do
    association :company, factory: :disclosure_company
    sequence(:edinet_document_id) { |n| format("S%07d", n) }
    fiscal_year_start_date { Date.new(2025, 4, 1) }
    fiscal_year_end_date { Date.new(2026, 3, 31) }
    filing_date { Date.new(2026, 6, 20) }
    accounting_standard { :ifrs }
    has_consolidated_statement { true }
  end

  factory :disclosure_financial_statement, class: "Disclosure::FinancialStatement" do
    association :report, factory: :disclosure_report
    consolidation_type { :consolidated }
    accounting_standard { :ifrs }
    presentation_format { "ifrs_classified" }
    is_primary { true }

    # 科目をtransientで渡せるようにしてテストを読みやすくする:
    #   create(:disclosure_financial_statement, items_hash: { "bs.assets" => 100, ... })
    transient { items_hash { {} } }
    after(:create) do |fs, evaluator|
      evaluator.items_hash.each do |code, amount|
        create(:disclosure_financial_statement_item,
               financial_statement: fs, item_code: code, amount: amount)
      end
    end
  end

  factory :disclosure_financial_statement_item, class: "Disclosure::FinancialStatementItem" do
    association :financial_statement, factory: :disclosure_financial_statement
    item_code { "bs.assets" }
    amount { 1_000_000 }
  end
end
