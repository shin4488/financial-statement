require "rails_helper"

RSpec.describe Ingestion::FormatDetector do
  subject(:detector) { described_class.new }

  # FormatDetectorがxbrlに要求するのはmoneyだけなので最小のスタブで足りる。
  # present_tags: 「実在する」とみなすタグ名の一覧（それ以外はnil = タグなし）
  def xbrl_with(*present_tags)
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, _ctx| present_tags.include?(qname) ? 1_000 : nil }
    end
  end

  def detect(xbrl, standard, industry, consolidation: "")
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

    it "業種コードが銀行・保険でも流動資産タグを持つ財務諸表（持株会社の単体など）は一般になる" do
      aggregate_failures do
        expect(detect(general_xbrl, "japan_gaap", "bnk")).to eq "jgaap_general"
        expect(detect(general_xbrl, "japan_gaap", "ins")).to eq "jgaap_general"
      end
    end

    it "流動資産タグは判定対象の連結/単体コンテキストで探す" do
      xbrl = xbrl_with("jppfs_cor:CurrentAssets")
      allow(xbrl).to receive(:money).with("jppfs_cor:CurrentAssets", "CurrentYearInstant").and_return(nil)
      allow(xbrl).to receive(:money).with("jppfs_cor:CurrentAssets", "CurrentYearInstant_NonConsolidatedMember").and_return(1_000)
      expect(detect(xbrl, "japan_gaap", "ins", consolidation: "")).to eq "jgaap_insurance"
      expect(detect(xbrl, "japan_gaap", "ins", consolidation: "_NonConsolidatedMember")).to eq "jgaap_general"
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

  it "US GAAPはunsupportedになる" do
    expect(detect(nil, "us_gaap", nil)).to eq "unsupported"
  end
end
