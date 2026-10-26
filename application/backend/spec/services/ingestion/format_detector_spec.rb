require "rails_helper"

RSpec.describe Ingestion::FormatDetector do
  subject(:detector) { described_class.new }

  # 連結の当期の値があるタグだけを持つXBRL（ほかのタグはない）。instant は当期末の残高のタグ、duration は当期の損益のタグ
  def xbrl_with(*instant, duration: [])
    facts = instant.to_h { |qname| [ [ qname, "CurrentYearInstant" ], 1_000 ] }
              .merge(duration.to_h { |qname| [ [ qname, "CurrentYearDuration" ], 1_000 ] })
    synthetic_xbrl_document(facts: facts)
  end

  def detect(xbrl, standard, industry, consolidation: :consolidated)
    detector.detect(xbrl, accounting_standard: standard, industry_code: industry, consolidation: consolidation)
  end

  describe "日本基準" do
    let(:general_xbrl) { xbrl_with("jppfs_cor:CurrentAssets") } # 流動/固定区分のあるBS
    let(:financial_xbrl) { xbrl_with }                             # 流動資産タグのないBS（金融機関の様式）

    it "業種DEIなし・cteは一般になる" do
      aggregate_failures do
        [ nil, "", "cte", "CTE" ].each do |industry|
          expect(detect(general_xbrl, "japan_gaap", industry)).to eq "jgaap_general"
        end
      end
    end

    it "業種別の勘定科目を持つ業種（建設・鉄道・電気・証券など）も骨格が同じなので一般になる" do
      aggregate_failures do
        %w[cns CNS rwy ele elc gas wat sec spf cmd ivt inv].each do |industry|
          expect(detect(general_xbrl, "japan_gaap", industry)).to eq "jgaap_general"
        end
      end
    end

    it "銀行は銀行、保険は保険になる（大文字小文字は問わない）" do
      aggregate_failures do
        %w[bnk BNK].each { |i| expect(detect(financial_xbrl, "japan_gaap", i)).to eq "jgaap_bank" }
        %w[ins INS].each { |i| expect(detect(financial_xbrl, "japan_gaap", i)).to eq "jgaap_insurance" }
      end
    end

    it "複数業種コード（カンマ区切り）は先頭を主たる業種として判定する" do
      aggregate_failures do
        expect(detect(financial_xbrl, "japan_gaap", "bnk,ins")).to eq "jgaap_bank"
        expect(detect(general_xbrl, "japan_gaap", "cte,cns")).to eq "jgaap_general"
        expect(detect(general_xbrl, "japan_gaap", "cte,sec,cmd")).to eq "jgaap_general"
      end
    end

    it "銀行と保険を並べる会社は、経常収益のタグがある業種の様式になる（先頭が銀行でも、保険の経常収益だけなら保険）" do
      aggregate_failures do
        expect(detect(xbrl_with(duration: %w[jppfs_cor:OperatingIncomeINS]), "japan_gaap", "BNK,INS")).to eq "jgaap_insurance"
        expect(detect(xbrl_with(duration: %w[jppfs_cor:OrdinaryIncomeBNK]), "japan_gaap", "bnk,ins")).to eq "jgaap_bank"
        expect(detect(xbrl_with(duration: %w[jppfs_cor:OrdinaryIncomeBNK jppfs_cor:OperatingIncomeINS]), "japan_gaap", "bnk,ins"))
          .to eq "jgaap_bank"
      end
    end

    it "業種コードが銀行・保険でも流動資産タグを持つ財務諸表（持株会社の単体など）は一般になる" do
      aggregate_failures do
        expect(detect(general_xbrl, "japan_gaap", "bnk")).to eq "jgaap_general"
        expect(detect(general_xbrl, "japan_gaap", "ins")).to eq "jgaap_general"
      end
    end

    it "流動資産タグは判定対象の連結/単体コンテキストで探す" do
      # 流動資産は単体にだけある
      xbrl = synthetic_xbrl_document(facts: { [ "jppfs_cor:CurrentAssets", "CurrentYearInstant_NonConsolidatedMember" ] => 1_000 })
      expect(detect(xbrl, "japan_gaap", "ins", consolidation: :consolidated)).to eq "jgaap_insurance"
      expect(detect(xbrl, "japan_gaap", "ins", consolidation: :non_consolidated)).to eq "jgaap_general"
    end
  end

  describe "IFRS" do
    it "流動資産タグが実在すればclassified、資産合計のみならliquidity" do
      expect(detect(xbrl_with("jpigp_cor:CurrentAssetsIFRS"), "ifrs", "cte")).to eq "ifrs_classified"
      expect(detect(xbrl_with("jpigp_cor:AssetsIFRS"), "ifrs", "INS")).to eq "ifrs_liquidity"
    end

    it "本表タグが1つも無い書類（詳細タグ付け義務化前）はsummaryになる" do
      expect(detect(xbrl_with, "ifrs", "cte")).to eq "ifrs_summary"
    end
  end

  it "US GAAPはタグの内容によらず、経営指標の要約で構成するusgaap_summaryになる" do
    expect(detect(xbrl_with("jppfs_cor:CurrentAssets"), "us_gaap", nil)).to eq "usgaap_summary"
  end
end
