require "rails_helper"

# 公開API ingest を合成XBRLで通す（EDINET非接続）。
# DEI検証 → 形式判定 → 抽出 → 保存 の実経路で、DB反映のルールを検証する
RSpec.describe Ingestion::ReportIngester do
  def ingest(doc_id, xml, expected_sec_code: nil)
    client = FakeEdinetClient.new(doc_id => xml)
    Dir.mktmpdir do |work_dir|
      described_class.new(client: client)
                     .ingest(doc_id: doc_id, work_dir: work_dir, expected_sec_code: expected_sec_code)
    end
  end

  # 日本基準・単体のみの最小の有報。items は科目コードでなくXBRLタグで与える
  def annual_report_xml(name_ja: "テスト株式会社", fy_start: "2025-04-01", fy_end: "2026-03-31",
                        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 })
    synthetic_xbrl_xml(
      dei: { name_ja: name_ja, fiscal_year_start_date: fy_start, fiscal_year_end_date: fy_end },
      facts: facts)
  end

  describe "企業名の保存（社名変更対応）" do
    it "各有報には提出時点の企業名が保存され、企業マスタは最新期の名前になる" do
      ingest("S0000001", annual_report_xml(name_ja: "旧社名株式会社", fy_start: "2024-04-01", fy_end: "2025-03-31"))
      ingest("S0000002", annual_report_xml(name_ja: "新社名株式会社"))

      expect(Disclosure::Report.order(:fiscal_year_end_date).pluck(:company_name_ja))
        .to eq %w[旧社名株式会社 新社名株式会社]
      expect(Disclosure::Company.find_by(edinet_code: "E00001").name_ja).to eq "新社名株式会社"
    end

    it "過去年度を後から取り込んでも企業マスタの名前は巻き戻らない" do
      ingest("S0000002", annual_report_xml(name_ja: "新社名株式会社"))
      ingest("S0000001", annual_report_xml(name_ja: "旧社名株式会社", fy_start: "2024-04-01", fy_end: "2025-03-31"))

      expect(Disclosure::Company.find_by(edinet_code: "E00001").name_ja).to eq "新社名株式会社"
      expect(Disclosure::Report.order(:fiscal_year_end_date).pluck(:company_name_ja))
        .to eq %w[旧社名株式会社 新社名株式会社]
    end

    it "同じ期の再取込（訂正有報）は有報・マスタ両方の名前を上書きする" do
      ingest("S0000001", annual_report_xml(name_ja: "誤った社名"))
      ingest("S0000009", annual_report_xml(name_ja: "訂正後の社名"))

      expect(Disclosure::Report.sole.company_name_ja).to eq "訂正後の社名"
      expect(Disclosure::Company.find_by(edinet_code: "E00001").name_ja).to eq "訂正後の社名"
    end
  end

  describe "科目の永続化" do
    it "再取込で科目は総入れ替えされ、開示されなくなった科目の行が残らない" do
      ingest("S0000001", annual_report_xml(
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
                 [ "jppfs_cor:NetAssets", "CurrentYearInstant_NonConsolidatedMember" ] => 50 }))
      ingest("S0000009", annual_report_xml(
        facts: { [ "jppfs_cor:NetAssets", "CurrentYearInstant_NonConsolidatedMember" ] => 50 }))

      fs = Disclosure::FinancialStatement.sole
      expect(fs.items.pluck(:item_code, :amount)).to eq [ [ "bs.equity", 50 ] ]
    end

    it "科目が空の再取込（財務factなしの訂正有報）では既存の科目・形式を保持する" do
      ingest("S0000001", annual_report_xml)
      ingest("S0000009", annual_report_xml(facts: {}))

      fs = Disclosure::FinancialStatement.sole
      expect(fs.items.pluck(:item_code, :amount)).to eq [ [ "bs.assets", 100 ] ]
      expect(fs.presentation_format).to eq "jgaap_general"
    end
  end

  describe "primaryの財務諸表でbs.assetsが無いときの警告" do
    it "BSを抽出する形式では形式判定ミスの可能性として警告する" do
      expect(Sentry).to receive(:capture_message)
        .with(/primary statement missing bs\.assets/, level: :warning)
      ingest("S0000001", annual_report_xml(
        facts: { [ "jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember" ] => 100 }))
    end

    it "BSを抽出しない形式（ifrs_summaryなど）では警告しない" do
      expect(Sentry).not_to receive(:capture_message).with(/primary statement missing bs\.assets/, anything)
      # 詳細タグの無いIFRS有報（経営指標サマリのみ）→ ifrs_summary
      ingest("S0000001", synthetic_xbrl_xml(
        dei: { accounting_standard: "IFRS", has_consolidated: "true" },
        facts: { [ "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults", "CurrentYearDuration" ] => 100 }))

      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).presentation_format)
        .to eq "ifrs_summary"
    end

    it "Extractorを持たない形式（unsupported）では警告しない" do
      expect(Sentry).not_to receive(:capture_message).with(/primary statement missing bs\.assets/, anything)
      ingest("S0000001", synthetic_xbrl_xml(dei: { accounting_standard: "US GAAP", has_consolidated: "true" }))

      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).presentation_format)
        .to eq "unsupported"
    end
  end

  describe "連結廃止の再取込" do
    it "取込に現れなくなった連結行が削除され、is_primaryの重複が残らない" do
      ingest("S0000001", synthetic_xbrl_xml(
        dei: { has_consolidated: "true" },
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 200,
                 [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 }))
      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).is_primary).to be true

      ingest("S0000009", annual_report_xml)

      fs = Disclosure::FinancialStatement.sole
      expect(fs.consolidation_type).to eq "non_consolidated"
      expect(fs.is_primary).to be true
    end
  end

  describe "取り込まない書類" do
    it "DEIのEDINETコードが不正な書類は保存しない（他社レコードの上書き防止）" do
      expect(Sentry).to receive(:capture_message).with(/invalid edinet code/, level: :error)
      ingest("S0000001", synthetic_xbrl_xml(dei: { edinet_code: "不正な値" }))
      expect(Disclosure::Company.count).to eq 0
    end

    it "書類一覧APIの証券コードとDEIの証券コードが食い違う書類は保存しない" do
      expect(Sentry).to receive(:capture_message).with(/sec code mismatch/, level: :error)
      ingest("S0000001", annual_report_xml, expected_sec_code: "72030")
      expect(Disclosure::Report.count).to eq 0
    end

    it "会計基準が判定できない書類は保存しない（形式判定できないため）" do
      expect(Sentry).to receive(:capture_message).with(/accounting standard unknown/, level: :warning)
      ingest("S0000001", synthetic_xbrl_xml(dei: { accounting_standard: nil }))
      expect(Disclosure::Report.count).to eq 0
    end

    it "XBRLを含まない書類（一部の訂正有報）は何もしない" do
      ingest("S0000001", nil)
      expect(Disclosure::Company.count).to eq 0
    end
  end
end
