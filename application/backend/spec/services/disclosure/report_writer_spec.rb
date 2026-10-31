require "rails_helper"

RSpec.describe Disclosure::ReportWriter do
  let(:writer) { described_class.new }
  let(:events) { [] }

  def dei(**overrides)
    Ingestion::DeiExtractor::Result.new(
      edinet_code: "E00001", stock_code: "45020", name_ja: "テスト株式会社", accounting_standard: "japan_gaap",
      has_consolidated: true, fiscal_year_start_date: "2025-04-01", fiscal_year_end_date: "2026-03-31",
      filing_date: "2026-06-20", **overrides)
  end

  def statement(consolidation_type, items, presentation_format: "jgaap_general")
    amounts = FinancialStatements::Amounts.new
    items.each { |code, amount| amounts.store(code, amount, 1.to_d) }
    FinancialStatements::StatementData.new(consolidation_type: consolidation_type, accounting_standard: "japan_gaap",
                                           presentation_format: presentation_format, amounts: amounts,
                                           disclosed_roe: 0.1.to_d, fiscal_year_end_date: nil)
  end

  # ブロックが呼ばれた時点の、渡された財務諸表の状態と、ほかの区分の財務諸表の数を記録する
  def save(doc_id, dei, stock_code, statements)
    writer.save(doc_id, dei, stock_code, statements) do |event, statement_data, financial_statement|
      events << [ event, statement_data.consolidation_type, financial_statement.consolidation_type,
                  financial_statement.is_primary,
                  Disclosure::FinancialStatementItem.where(financial_statement: financial_statement).pluck(:item_code, :amount, :rounding_error),
                  Disclosure::FinancialStatement.count ]
    end
  end

  describe "#save" do
    it "区分ごとに、書いた直後にその区分の値と財務諸表を :saved で渡す。主は連結にし、企業マスタには渡された証券コードを保存する" do
      save("S0000001", dei(stock_code: ""), "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100 }) ])

      aggregate_failures do
        expect(events).to eq [
          [ :saved, :consolidated, "consolidated", true, [ [ "bs.assets", 200, 1.to_d ] ], 1 ],
          [ :saved, :non_consolidated, "non_consolidated", false, [ [ "bs.assets", 100, 1.to_d ] ], 2 ]
        ]
        expect(Disclosure::Company.sole).to have_attributes(edinet_code: "E00001", stock_code: "45020", name_ja: "テスト株式会社")
        expect(Disclosure::Report.sole).to have_attributes(edinet_document_id: "S0000001", has_consolidated_statement: true)
      end
    end

    it "連結に貸借対照表だけがあり、単体に当期の損益・CFがあれば、単体を主にする" do
      save("S0000001", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }),
             statement(:non_consolidated, { "bs.assets" => 100, "pl.profit" => 10, "cf.operating" => 20 }) ])

      expect(events.map { |event| event.first(4) }).to eq [ [ :saved, :consolidated, "consolidated", false ],
                                                             [ :saved, :non_consolidated, "non_consolidated", true ] ]
    end

    {
      "連結に当期の損益があれば" => [ { "bs.assets" => 200, "pl.profit" => 20 }, "jgaap_general" ],
      "連結に資産合計がなければ（未対応の形式など）" => [ {}, "unsupported" ]
    }.each do |condition, (consolidated_items, presentation_format)|
      it "#{condition}、単体に当期の損益があっても連結を主にする" do
        save("S0000001", dei, "45020",
             [ statement(:consolidated, consolidated_items, presentation_format: presentation_format),
               statement(:non_consolidated, { "bs.assets" => 100, "pl.profit" => 10 }) ])

        expect(Disclosure::FinancialStatement.where(is_primary: true).pluck(:consolidation_type)).to eq [ "consolidated" ]
      end
    end

    it "主が連結から単体に替わる再取込でも、新しい主を立てる前に旧い主を外す（1有報に主は1つの一意制約に反しない）" do
      save("S0000001", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200, "pl.profit" => 20 }),
             statement(:non_consolidated, { "bs.assets" => 100, "pl.profit" => 10 }) ])

      save("S0000009", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100, "pl.profit" => 10 }) ])

      expect(Disclosure::FinancialStatement.where(is_primary: true).pluck(:consolidation_type)).to eq [ "non_consolidated" ]
    end

    it "連結を作成しない書類は単体を主にする" do
      save("S0000001", dei(has_consolidated: false), "45020", [ statement(:non_consolidated, { "bs.assets" => 100 }) ])

      expect(events.map { |event| event.first(4) }).to eq [ [ :saved, :non_consolidated, "non_consolidated", true ] ]
    end

    it "当期の科目がない区分は、既存の科目があれば書き換えずに :skipped で渡し、ほかの区分は保存する" do
      save("S0000001", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100 }) ])
      kept = Disclosure::FinancialStatement.find_by!(consolidation_type: :non_consolidated).attributes
      events.clear

      save("S0000009", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 300 }), statement(:non_consolidated, { "bs.assets_begin" => 90 }) ])

      aggregate_failures do
        expect(events).to eq [
          [ :saved, :consolidated, "consolidated", true, [ [ "bs.assets", 300, 1.to_d ] ], 2 ],
          [ :skipped, :non_consolidated, "non_consolidated", false, [ [ "bs.assets", 100, 1.to_d ] ], 2 ]
        ]
        expect(Disclosure::FinancialStatement.find_by!(consolidation_type: :non_consolidated).attributes).to eq kept
      end
    end

    it "既存の行がない区分は、当期の科目がなくても空のまま :saved で作る" do
      save("S0000001", dei(has_consolidated: false), "45020", [ statement(:non_consolidated, {}, presentation_format: "unsupported") ])

      expect(events).to eq [ [ :saved, :non_consolidated, "non_consolidated", true, [], 1 ] ]
    end

    it "今回の区分にない財務諸表を消す" do
      save("S0000001", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100 }) ])

      save("S0000009", dei(has_consolidated: false), "45020", [ statement(:non_consolidated, { "bs.assets" => 100 }) ])

      expect(Disclosure::FinancialStatement.pluck(:consolidation_type, :is_primary)).to eq [ [ "non_consolidated", true ] ]
    end

    it "主が単体から連結に替わるときは、新しい主を立てる前に旧い主を外す（1有報に主は1つの一意制約に反しない）" do
      save("S0000001", dei(has_consolidated: false), "45020", [ statement(:non_consolidated, { "bs.assets" => 100 }) ])
      events.clear

      save("S0000009", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100 }) ])

      aggregate_failures do
        expect(events.map { |event| event.first(4) }).to eq [ [ :saved, :consolidated, "consolidated", true ],
                                                               [ :saved, :non_consolidated, "non_consolidated", false ] ]
        expect(Disclosure::FinancialStatement.where(is_primary: true).pluck(:consolidation_type)).to eq [ "consolidated" ]
      end
    end
  end

  describe "#exclude_from_listing" do
    it "同じ書類IDの主の財務諸表だけを表示から外し、主でない財務諸表と科目は残す" do
      save("S0000001", dei, "45020",
           [ statement(:consolidated, { "bs.assets" => 200 }), statement(:non_consolidated, { "bs.assets" => 100 }) ])
      non_consolidated = Disclosure::FinancialStatement.find_by!(consolidation_type: :non_consolidated).attributes

      writer.exclude_from_listing("S0000001")

      aggregate_failures do
        expect(Disclosure::FinancialStatement.where(is_primary: true)).to be_empty
        expect(Disclosure::FinancialStatement.find_by!(consolidation_type: :non_consolidated).attributes).to eq non_consolidated
        expect(Disclosure::FinancialStatementItem.count).to eq 2
      end
    end

    it "同じ書類IDの書類がなければ何もしない" do
      save("S0000001", dei, "45020", [ statement(:consolidated, { "bs.assets" => 200 }) ])
      saved = Disclosure::FinancialStatement.sole.attributes

      writer.exclude_from_listing("S0000002")

      expect(Disclosure::FinancialStatement.sole.attributes).to eq saved
    end
  end
end
