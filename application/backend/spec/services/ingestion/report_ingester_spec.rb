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
    it "context IDの命名を変えても同じ年度の三表・公表ROEを保存できる" do
      [ "standard", "Prior3Year", "arbitrary" ].each_with_index do |naming, index|
        suffix = "_NonConsolidatedMember"
        xml = synthetic_xbrl_xml(facts: {
          [ "jppfs_cor:Assets", "CurrentYearInstant#{suffix}" ] => 100 + index,
          [ "jppfs_cor:Assets", "Prior1YearInstant#{suffix}" ] => 80,
          [ "jppfs_cor:NetSales", "CurrentYearDuration#{suffix}" ] => 200,
          [ "jppfs_cor:ProfitLoss", "CurrentYearDuration#{suffix}" ] => 20,
          [ "jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant#{suffix}" ] => 8,
          [ "jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant#{suffix}" ] => 10,
          [ "jppfs_cor:NetCashProvidedByUsedInOperatingActivities", "CurrentYearDuration#{suffix}" ] => 2,
          [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration#{suffix}" ] => "0.25"
        })
        if naming != "standard"
          ids = [ "CurrentYearInstant#{suffix}", "Prior1YearInstant#{suffix}", "CurrentYearDuration#{suffix}" ]
          ids.each_with_index do |id, i|
            renamed = naming == "Prior3Year" ? id.sub("CurrentYear", "Prior3Year").sub("Prior1Year", "Prior4Year") : "context_#{i}"
            xml = xml.gsub(id, renamed)
          end
        end
        ingest("S0000001", xml)
        fs = Disclosure::FinancialStatement.sole
        expect(fs.items_hash).to include("bs.assets" => 100 + index, "bs.assets_begin" => 80,
                                        "pl.revenue" => 200, "pl.profit" => 20,
                                        "cf.cash_begin" => 8, "cf.cash_end" => 10, "cf.operating" => 2)
        expect(fs.disclosed_roe).to eq "0.25".to_d
      end
    end

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

    it "期首残高だけの再取込では既存の当期科目・形式・公表ROEを保持する" do
      ingest("S0000001", annual_report_xml(facts: {
        [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
        [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.123"
      }))
      fs = Disclosure::FinancialStatement.sole
      previous_attributes = fs.attributes
      previous_items = fs.items.map(&:attributes)

      ingest("S0000001", annual_report_xml(facts: {
        [ "jppfs_cor:Assets", "Prior1YearInstant_NonConsolidatedMember" ] => 80,
        [ "jppfs_cor:ShareholdersEquity", "Prior1YearInstant_NonConsolidatedMember" ] => 40,
        [ "jppfs_cor:ValuationAndTranslationAdjustments", "Prior1YearInstant_NonConsolidatedMember" ] => 5,
        [ "jppfs_cor:CashAndCashEquivalents", "Prior1YearInstant_NonConsolidatedMember" ] => 10
      }))

      expect(fs.reload.attributes).to eq previous_attributes
      expect(fs.items.reload.map(&:attributes)).to eq previous_items
    end
  end

  describe "企業公表ROEの保存" do
    it "計算用科目とは別に小数を保存し、訂正・未開示への変更も反映する" do
      facts = {
        [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
        [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.1234567"
      }
      ingest("S0000001", annual_report_xml(facts: facts))
      fs = Disclosure::FinancialStatement.sole
      expect(fs.disclosed_roe).to eq 0.1234567.to_d
      expect(fs.disclosed_roe_checked_at).not_to be_nil
      facts[facts.keys.last] = "-0.02"
      ingest("S0000001", annual_report_xml(facts: facts))
      expect(fs.reload.disclosed_roe).to eq(-0.02.to_d)
      ingest("S0000001", annual_report_xml)
      expect(fs.reload.disclosed_roe).to be_nil
      expect(fs.disclosed_roe_checked_at).not_to be_nil
    end

    it "財務factのない訂正書類では既存公表値を消さない" do
      ingest("S0000001", annual_report_xml(facts: {
        [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
        [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.123"
      }))
      ingest("S0000001", annual_report_xml(facts: {}))
      expect(Disclosure::FinancialStatement.sole.disclosed_roe).to eq 0.123.to_d
    end
  end

  describe "primaryの財務諸表でbs.assetsが無いときの警告" do
    it "BSを抽出する形式では形式判定ミスの可能性として警告する" do
      expect(Sentry).to receive(:capture_message)
        .with(/primary statement missing bs\.assets/, level: :warning)
      ingest("S0000001", annual_report_xml(
        facts: { [ "jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember" ] => 100 }))
    end

    it "ifrs_summaryで指標用の総資産を取得できれば警告しない" do
      expect(Sentry).not_to receive(:capture_message).with(/primary statement missing bs\.assets/, anything)
      # 詳細タグの無いIFRS有報（経営指標サマリのみ）→ ifrs_summary
      ingest("S0000001", synthetic_xbrl_xml(
        dei: { accounting_standard: "IFRS", has_consolidated: "true" },
        facts: { [ "jpcrp_cor:RevenueIFRSSummaryOfBusinessResults", "CurrentYearDuration" ] => 100,
                 [ "jpcrp_cor:TotalAssetsIFRSSummaryOfBusinessResults", "CurrentYearInstant" ] => 200 }))

      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).presentation_format)
        .to eq "ifrs_summary"
    end

    it "usgaap_summaryで指標用の総資産を取得できれば警告しない" do
      expect(Sentry).not_to receive(:capture_message).with(/primary statement missing bs\.assets/, anything)
      ingest("S0000001", synthetic_xbrl_xml(
        dei: { accounting_standard: "US GAAP", has_consolidated: "true" },
        facts: { [ "jpcrp_cor:TotalAssetsUSGAAPSummaryOfBusinessResults", "CurrentYearInstant" ] => 200 }))

      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :consolidated).presentation_format)
        .to eq "usgaap_summary"
    end
  end

  describe "売上と経営指標の要約の照合の警告" do
    let(:context) { "CurrentYearDuration_NonConsolidatedMember" }
    let(:assets) { { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 1_000 } }

    before { allow(Sentry).to receive(:capture_message) }

    it "売上が要約の売上と合わなければ、照合の種類ごとの固定の文言で警告し、その文言でissueをまとめ、書類ID・連結区分・金額を付加情報にする" do
      ingest("S0000001", annual_report_xml(facts: assets.merge(
        [ "jppfs_cor:NetSales", context ] => 107,
        [ "jpcrp030000-asr_E00001-000:BusinessRevenueSummaryOfBusinessResults", context ] => 615)))

      expect(Sentry).to have_received(:capture_message).with(
        "revenue does not match summary of business results", level: :warning,
        fingerprint: [ "revenue does not match summary of business results" ],
        extra: { doc_id: "S0000001", consolidation_type: "non_consolidated", presentation_format: "jgaap_general",
                 amounts: { "pl.revenue" => 107, "pl.summary_revenue" => 615 } })
    end

    it "要約に売上があるのに売上が取れなければ警告する" do
      ingest("S0000001", annual_report_xml(facts: assets.merge(
        [ "jpcrp030000-asr_E00001-000:OperatingRevenuesSummaryOfBusinessResults", context ] => 110)))

      expect(Sentry).to have_received(:capture_message).with(
        "revenue missing although summary of business results has revenue", level: :warning,
        fingerprint: [ "revenue missing although summary of business results has revenue" ],
        extra: hash_including(doc_id: "S0000001", amounts: { "pl.summary_revenue" => 110 }))
    end

    it "売上が要約の売上と一致すれば警告しない" do
      ingest("S0000001", annual_report_xml(facts: assets.merge(
        [ "jppfs_cor:NetSales", context ] => 615, [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ] => 615)))

      expect(Sentry).not_to have_received(:capture_message)
    end

    it "画面に出さない単体は照合しない" do
      ingest("S0000001", synthetic_xbrl_xml(
        dei: { has_consolidated: "true" },
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 1_000,
                 [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 615,
                 [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", "CurrentYearDuration" ] => 615,
                 [ "jppfs_cor:NetSales", context ] => 107,
                 [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ] => 615 }))

      expect(Sentry).not_to have_received(:capture_message)
    end
  end

  describe "日本基準のPLの照合の警告" do
    let(:context) { "CurrentYearDuration_NonConsolidatedMember" }
    let(:assets) { { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 1_000 } }

    before { allow(Sentry).to receive(:capture_message) }

    it "費用のタグの組み合わせが売上と一致せず、1割以内のずれで描くときは、照合に使った金額を付けて警告する" do
      ingest("S0000001", annual_report_xml(facts: assets.merge(
        [ "jppfs_cor:NetSales", context ] => 1_000, [ "jppfs_cor:CostOfSales", context ] => 600,
        [ "jppfs_cor:SellingGeneralAndAdministrativeExpenses", context ] => 250, [ "jppfs_cor:OperatingIncome", context ] => 100)))

      expect(Sentry).to have_received(:capture_message).with(
        "profit and loss chart expenses do not reconcile", level: :warning,
        fingerprint: [ "profit and loss chart expenses do not reconcile" ],
        extra: { doc_id: "S0000001", consolidation_type: "non_consolidated", presentation_format: "jgaap_general",
                 amounts: { "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250, "pl.operating_profit" => 100 } })
    end

    it "費用のタグの組み合わせが売上と一致すれば警告しない" do
      ingest("S0000001", annual_report_xml(facts: assets.merge(
        [ "jppfs_cor:NetSales", context ] => 1_000, [ "jppfs_cor:CostOfSales", context ] => 600,
        [ "jppfs_cor:SellingGeneralAndAdministrativeExpenses", context ] => 300, [ "jppfs_cor:OperatingIncome", context ] => 100)))

      expect(Sentry).not_to have_received(:capture_message)
    end
  end

  describe "BSの照合の警告" do
    let(:context) { "CurrentYearInstant_NonConsolidatedMember" }
    let(:balance_sheet) do
      { [ "jppfs_cor:CurrentAssets", context ] => 400, [ "jppfs_cor:NoncurrentAssets", context ] => 589,
        [ "jppfs_cor:PropertyPlantAndEquipment", context ] => 589,
        [ "jppfs_cor:CurrentLiabilities", context ] => 300, [ "jppfs_cor:NoncurrentLiabilities", context ] => 300,
        [ "jppfs_cor:Liabilities", context ] => 600, [ "jppfs_cor:NetAssets", context ] => 400 }
    end

    before { allow(Sentry).to receive(:capture_message) }

    it "描くBSの借方の科目の合計が資産合計に届かなければ、照合に使った金額を付けて警告する" do
      ingest("S0000001", annual_report_xml(facts: balance_sheet.merge([ "jppfs_cor:Assets", context ] => 1_000)))

      expect(Sentry).to have_received(:capture_message).with(
        "balance sheet chart does not reconcile with totals", level: :warning,
        fingerprint: [ "balance sheet chart does not reconcile with totals" ],
        extra: { doc_id: "S0000001", consolidation_type: "non_consolidated", presentation_format: "jgaap_general",
                 amounts: { "bs.current_assets" => 400, "bs.tangible_fixed_assets" => 589, "bs.assets" => 1_000,
                            "bs.liabilities" => 600, "bs.equity" => 400 } })
    end

    it "繰延資産を借方に積んで資産合計と一致すれば警告しない" do
      ingest("S0000001", annual_report_xml(facts: balance_sheet.merge(
        [ "jppfs_cor:Assets", context ] => 1_000, [ "jppfs_cor:DeferredAssets", context ] => 11)))

      expect(Sentry).not_to have_received(:capture_message)
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

  describe "連結が加わる再取込" do
    it "単体だけの有報のあとに連結を含む訂正有報を取り込むと、画面に出す財務諸表が連結に替わる" do
      ingest("S0000001", annual_report_xml)
      expect(Disclosure::FinancialStatement.sole.is_primary).to be true

      ingest("S0000009", synthetic_xbrl_xml(
        dei: { has_consolidated: "true" },
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 200,
                 [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 }))

      expect(Disclosure::Report.sole.edinet_document_id).to eq "S0000009"
      expect(Disclosure::FinancialStatement.where(is_primary: true).pluck(:consolidation_type)).to eq [ "consolidated" ]
      expect(Disclosure::FinancialStatement.find_by(consolidation_type: :non_consolidated).is_primary).to be false
    end
  end

  describe "取り込まない書類" do
    it "証券コードが空でも既存書類・企業・期間が一致する再取込は可能" do
      ingest("S0000001", annual_report_xml)
      company = Disclosure::Company.sole
      ingest("S0000001", synthetic_xbrl_xml(dei: { stock_code: "" }, facts: {
        [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 200
      }))
      expect(Disclosure::FinancialStatement.sole.items_hash["bs.assets"]).to eq 200
      expect(company.reload.stock_code).to eq "45020"
    end

    it "企業マスタにも証券コードがない既存書類は、コードを推測せず再取込する" do
      ingest("S0000001", annual_report_xml)
      company = Disclosure::Company.sole
      company.update!(stock_code: "")
      ingest("S0000001", synthetic_xbrl_xml(dei: { stock_code: "" }, facts: {
        [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 200
      }))
      expect(Disclosure::FinancialStatement.sole.items_hash["bs.assets"]).to eq 200
      expect(company.reload.stock_code).to eq ""
      expect(Disclosure::Company.count).to eq 1
    end

    it "既存書類でも一覧APIの証券コードを照合できなければ更新しない" do
      ingest("S0000001", annual_report_xml)
      Disclosure::Company.sole.update!(stock_code: "")
      expect(Sentry).to receive(:capture_message).with(/sec code mismatch/, level: :error)
      ingest("S0000001", synthetic_xbrl_xml(dei: { stock_code: "" }), expected_sec_code: "45020")
      expect(Disclosure::FinancialStatement.sole.items_hash["bs.assets"]).to eq 100
    end

    it "証券コード欠損時、企業や会計期間が違う書類を既存有報に紐付けない" do
      ingest("S0000001", annual_report_xml)
      [ { edinet_code: "E99999" }, { fiscal_year_end_date: "2025-03-31" } ].each do |mismatch|
        ingest("S0000001", synthetic_xbrl_xml(dei: mismatch.merge(stock_code: "")))
      end
      expect(Disclosure::Report.count).to eq 1
      expect(Disclosure::FinancialStatement.sole.items_hash["bs.assets"]).to eq 100
    end

    it "過去に誤登録したファンドは企業比較から外し、保存済み科目と企業を保持する" do
      ingest("S0000001", annual_report_xml)
      fs = Disclosure::FinancialStatement.sole
      items = fs.items.map(&:attributes)
      company = fs.report.company.attributes
      ingest("S0000001", synthetic_xbrl_xml(facts: { [ "jpdei_cor:FundCodeDEI", "FilingDateInstant" ] => "G15497" }))
      expect(fs.reload.is_primary).to be false
      expect(fs.items.reload.map(&:attributes)).to eq items
      expect(fs.report.company.reload.attributes).to eq company
    end

    [ nil, "82530" ].each do |expected_sec_code|
      it "実際の信託受益証券を提出会社の有報として保存せず、企業マスタも変えない（一覧照合: #{expected_sec_code || 'なし'}）" do
        company = Disclosure::Company.create!(edinet_code: "E03041", stock_code: "82530", name_ja: "株式会社クレディセゾン")
        previous = company.attributes
        ingest("S100YZ8K", File.read(require_xbrl_fixture("S100YZ8K")), expected_sec_code: expected_sec_code)
        expect(Disclosure::Report.count).to eq 0
        expect(Disclosure::Company.count).to eq 1
        expect(company.reload.attributes).to eq previous
      end
    end

    it "表示から外した書類（主たる財務諸表がない有報）の会計期間が後でも、企業自身の最新期の有報で企業マスタを更新する" do
      # 信託受益証券の有報を企業の有報として取り込み、証券コードを空欄で上書きした後に、表示から外した状態
      company = Disclosure::Company.create!(edinet_code: "E03041", stock_code: "", name_ja: "株式会社クレディセゾン")
      fund = create(:disclosure_report, company: company, edinet_document_id: "S100YZ8K",
                    fiscal_year_start_date: Date.new(2025, 6, 13), fiscal_year_end_date: Date.new(2026, 5, 31))
      create(:disclosure_financial_statement, report: fund, consolidation_type: :non_consolidated, is_primary: false,
             items_hash: { "bs.assets" => 1_000 })

      ingest("S100YCDE", File.read(require_xbrl_fixture("S100YCDE")))

      expect(company.reload).to have_attributes(stock_code: "82530", name_ja: "株式会社クレディセゾン")
    end

    it "証券コードのある合成ファンドも除外する（CIで常時検証）" do
      ingest("S0000001", synthetic_xbrl_xml(facts: { [ "jpdei_cor:FundCodeDEI", "FilingDateInstant" ] => "G15497" }))
      expect(Disclosure::Company.count).to eq 0
    end

    it "一覧の証券コードがあっても書類自身の証券コードが空なら保存しない" do
      ingest("S0000001", synthetic_xbrl_xml(dei: { stock_code: "" }), expected_sec_code: "45020")
      expect(Disclosure::Company.count).to eq 0
    end

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
