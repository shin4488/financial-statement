require "rails_helper"

RSpec.describe Disclosure::FinancialStatement do
  describe "#to_statement_data" do
    let(:report) do
      create(:disclosure_report, fiscal_year_start_date: Date.new(2025, 1, 1), fiscal_year_end_date: Date.new(2025, 12, 31))
    end
    let!(:financial_statement) do
      create(:disclosure_financial_statement, report: report, consolidation_type: :non_consolidated,
             accounting_standard: :japan_gaap, presentation_format: "jgaap_general", disclosed_roe: 0.081.to_d).tap do |fs|
        create(:disclosure_financial_statement_item, financial_statement: fs, item_code: "bs.assets",
               amount: 100_000_000, rounding_error: 1_000_000)
      end
    end

    it "保存した連結区分（シンボルにする）・会計基準・形式・科目と端数・公表ROEと、有報の決算日を持つ" do
      statement_data = described_class.find(financial_statement.id).to_statement_data

      expect(statement_data).to have_attributes(consolidation_type: :non_consolidated, accounting_standard: "japan_gaap",
                                                presentation_format: "jgaap_general", disclosed_roe: 0.081.to_d,
                                                fiscal_year_end_date: Date.new(2025, 12, 31))
      expect(statement_data.amounts).to eq("bs.assets" => 100_000_000)
      expect(statement_data.amounts.rounding_errors).to eq("bs.assets" => 1_000_000)
      expect(statement_data.amounts).to be_frozen
    end

    it "有報から先読みした財務諸表と科目からは、問い合わせずに作る" do
      fs = Disclosure::Report.preload(primary_financial_statement: :items).find(report.id).primary_financial_statement

      expect(count_queries { fs.to_statement_data }).to eq 0
    end
  end
end
