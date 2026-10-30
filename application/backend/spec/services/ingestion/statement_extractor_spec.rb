require "rails_helper"

RSpec.describe Ingestion::StatementExtractor do
  it "科目ごとに対応表の期間で、指定の連結区分の値を引き、金額と端数を組で書く。取れない科目はキーを作らない" do
    # 期首の資産合計（bs.assets_begin）は、資産合計と同じタグの前期末を引く
    mapping = Ingestion::Mappings::Mapping.define("test") do
      item "bs.assets", "jppfs_cor:Assets"
      item "pl.operating_profit", "jppfs_cor:OperatingIncome"
      item "pl.sga", "jppfs_cor:Sga"
    end
    facts = { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 900,
              [ "jppfs_cor:Assets", "Prior1YearInstant_NonConsolidatedMember" ] => 800,
              [ "jppfs_cor:OperatingIncome", "CurrentYearDuration_NonConsolidatedMember" ] => 50,
              # 連結の値は読まない
              [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 1, [ "jppfs_cor:Sga", "CurrentYearDuration" ] => 1 }
    source = synthetic_xbrl_document(facts: facts, decimals: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => "0" })
    amounts = described_class.amounts(mapping, source: source, consolidation: :non_consolidated)
    aggregate_failures do
      expect(amounts.to_h).to eq("bs.assets" => 900, "pl.operating_profit" => 50, "bs.assets_begin" => 800)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1.to_d, "pl.operating_profit" => nil, "bs.assets_begin" => nil)
    end
  end

  describe "#extract" do
    include SyntheticXbrl

    def extract(dei:, facts:, detector: Ingestion::FormatDetector.new)
      document = synthetic_xbrl_document(dei: dei, facts: facts)
      parsed = Ingestion::DeiExtractor.new.extract(document)
      period = document.for_reporting_period(start_date: parsed.fiscal_year_start_date, end_date: parsed.fiscal_year_end_date)
      described_class.new.extract(period, parsed, detector: detector)
    end

    it "連結を作成する書類は、連結（DEIの会計基準・連結の業種コード）→ 単体（日本基準・単体の業種コード）の順に、区分の形式の対応表で科目を、区分の会計基準で公表ROEを取る" do
      # 連結はIFRSの流動資産があるため流動/非流動分類のIFRS、単体は流動資産のない銀行の様式になる
      statements = extract(
        dei: { accounting_standard: "IFRS", has_consolidated: "true",
               consolidated_industry_code: "cte", non_consolidated_industry_code: "bnk" },
        facts: { [ "jpigp_cor:CurrentAssetsIFRS", "CurrentYearInstant" ] => 120,
                 [ "jpigp_cor:AssetsIFRS", "CurrentYearInstant" ] => 300,
                 [ "jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults", "CurrentYearDuration" ] => "0.1",
                 [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
                 [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.05" })

      aggregate_failures do
        expect(statements.map { |data| [ data.consolidation_type, data.accounting_standard, data.presentation_format,
                                         data.amounts.to_h, data.disclosed_roe, data.fiscal_year_end_date ] }).to eq [
          [ :consolidated, "ifrs", "ifrs_classified", { "bs.current_assets" => 120, "bs.assets" => 300 }, 0.1.to_d, nil ],
          [ :non_consolidated, "japan_gaap", "jgaap_bank", { "bs.assets" => 100 }, 0.05.to_d, nil ]
        ]
        expect(statements).to all(be_a(FinancialStatements::StatementData))
        expect(statements.map(&:amounts)).to all(be_frozen)
      end
    end

    it "連結を作成しない書類は、単体だけを取る" do
      statements = extract(dei: { has_consolidated: "false" },
                           facts: { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 300,
                                    [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 })

      expect(statements.map { |data| [ data.consolidation_type, data.presentation_format, data.amounts.to_h ] })
        .to eq [ [ :non_consolidated, "jgaap_general", { "bs.assets" => 100 } ] ]
    end

    it "形式に対応表がない区分（unsupported）は、科目を空にし、公表ROEは区分の会計基準で取る" do
      unsupported = Class.new { def detect(*, **) = FinancialStatements::Formats::UNSUPPORTED }.new
      statements = extract(
        dei: { has_consolidated: "false" },
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
                 [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.05" },
        detector: unsupported)

      expect(statements.map { |data| [ data.presentation_format, data.amounts.to_h, data.amounts.rounding_errors, data.disclosed_roe ] })
        .to eq [ [ "unsupported", {}, {}, 0.05.to_d ] ]
    end
  end
end
