require "rails_helper"

RSpec.describe Ingestion::ReportIngester do
  subject(:ingester) { described_class.new }

  # persistはEDINETアクセスなしで検証できる境界なので、DeiExtractor::Resultを
  # 直接組み立てて呼ぶ（XBRLフィクスチャ不要でDB反映のルールを網羅するため）
  def dei(name_ja:, fy_start:, fy_end:, stock_code: "45020", has_consolidated: false)
    Ingestion::DeiExtractor::Result.new(
      edinet_code: "E99999", stock_code: stock_code, name_ja: name_ja, name_en: nil,
      accounting_standard: "japan_gaap", has_consolidated: has_consolidated,
      fiscal_year_start_date: fy_start, fiscal_year_end_date: fy_end,
      filing_date: nil, consolidated_industry_code: nil, non_consolidated_industry_code: nil)
  end

  def extraction(consolidation_type, items: { "bs.assets" => 100 })
    Ingestion::ReportIngester::Extraction.new(
      consolidation_type: consolidation_type, accounting_standard: "japan_gaap",
      format: "jgaap_general", items: items)
  end

  def statements
    [ extraction(:non_consolidated) ]
  end

  def persist(doc_id, dei_result)
    ingester.send(:persist, doc_id, dei_result, statements)
  end

  describe "企業名の保存（社名変更対応）" do
    it "各有報には提出時点の企業名が保存され、企業マスタは最新期の名前になる" do
      persist("S0000001", dei(name_ja: "旧社名株式会社", fy_start: "2024-04-01", fy_end: "2025-03-31"))
      persist("S0000002", dei(name_ja: "新社名株式会社", fy_start: "2025-04-01", fy_end: "2026-03-31"))

      names = Disclosure::Report.order(:fiscal_year_end_date).pluck(:company_name_ja)
      expect(names).to eq %w[旧社名株式会社 新社名株式会社]
      expect(Disclosure::Company.find_by(edinet_code: "E99999").name_ja).to eq "新社名株式会社"
    end

    it "過去年度を後から取り込んでも企業マスタの名前は巻き戻らない" do
      persist("S0000002", dei(name_ja: "新社名株式会社", fy_start: "2025-04-01", fy_end: "2026-03-31"))
      persist("S0000001", dei(name_ja: "旧社名株式会社", fy_start: "2024-04-01", fy_end: "2025-03-31"))

      company = Disclosure::Company.find_by(edinet_code: "E99999")
      expect(company.name_ja).to eq "新社名株式会社"
      expect(Disclosure::Report.order(:fiscal_year_end_date).pluck(:company_name_ja))
        .to eq %w[旧社名株式会社 新社名株式会社]
    end

    it "同じ期の再取込（訂正有報）は有報・マスタ両方の名前を上書きする" do
      persist("S0000001", dei(name_ja: "誤った社名", fy_start: "2025-04-01", fy_end: "2026-03-31"))
      persist("S0000009", dei(name_ja: "訂正後の社名", fy_start: "2025-04-01", fy_end: "2026-03-31"))

      expect(Disclosure::Report.count).to eq 1
      expect(Disclosure::Report.first.company_name_ja).to eq "訂正後の社名"
      expect(Disclosure::Company.find_by(edinet_code: "E99999").name_ja).to eq "訂正後の社名"
    end
  end

  describe "科目の永続化" do
    it "再取込で科目は総入れ替えされ、開示されなくなった科目の行が残らない" do
      persist("S0000001", dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31"))
      fewer_items = [ extraction(:non_consolidated, items: { "bs.equity" => 50 }) ]
      ingester.send(:persist, "S0000002",
                    dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31"), fewer_items)

      fs = Disclosure::FinancialStatement.sole
      expect(fs.items.pluck(:item_code, :amount)).to eq [ [ "bs.equity", 50 ] ]
    end

    it "科目が空の再取込（財務factなしの訂正有報）では既存の科目・形式を保持する" do
      persist("S0000001", dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31"))
      empty = [ extraction(:non_consolidated, items: {}) ]
      ingester.send(:persist, "S0000009",
                    dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31"), empty)

      fs = Disclosure::FinancialStatement.sole
      expect(fs.items.pluck(:item_code, :amount)).to eq [ [ "bs.assets", 100 ] ]
      expect(fs.presentation_format).to eq "jgaap_general"
    end
  end

  describe "連結廃止の再取込" do
    it "取込に現れなくなった連結行が削除され、is_primaryの重複が残らない" do
      both = [ extraction(:consolidated), extraction(:non_consolidated) ]
      ingester.send(:persist, "S0000001",
                    dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31",
                        has_consolidated: true), both)
      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).is_primary).to be true

      persist("S0000009", dei(name_ja: "テスト", fy_start: "2025-04-01", fy_end: "2026-03-31"))

      fs = Disclosure::FinancialStatement.sole
      expect(fs.consolidation_type).to eq "non_consolidated"
      expect(fs.is_primary).to be true
    end
  end
end
