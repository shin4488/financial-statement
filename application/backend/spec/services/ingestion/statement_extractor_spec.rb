require "rails_helper"

RSpec.describe Ingestion::StatementExtractor do
  # 評価する科目（科目コード・期間・取得式）の一覧と、科目コードから取得式を引く口だけを持つ対応表
  let(:item_class) { Struct.new(:code, :period, :expression) }

  def mapping_of(*items)
    entries = items.map { |code, period, spec| item_class.new(code, period, Ingestion::Expressions.wrap(spec)) }
    double("mapping", items: entries).tap do |mapping|
      allow(mapping).to receive(:expression) { |code| entries.find { |entry| entry.code == code }&.expression }
    end
  end

  # facts・errors: { [qname, 標準のコンテキストID] => 値 }
  def source_with(facts, errors: {})
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, context| facts[[ qname, context ]] }
      allow(xbrl).to receive(:rounding_error) { |qname, context| errors[[ qname, context ]] }
    end
  end

  it "科目ごとに対応表の期間で、指定の連結区分の値を引き、金額と端数を組で書く。取れない科目はキーを作らない" do
    mapping = mapping_of([ "bs.assets", :instant, "t:Assets" ], [ "pl.operating_profit", :duration, "t:OperatingIncome" ],
                         [ "bs.assets_begin", :prior_instant, "t:Assets" ], [ "pl.sga", :duration, "t:Sga" ])
    facts = { [ "t:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 900,
              [ "t:Assets", "Prior1YearInstant_NonConsolidatedMember" ] => 800,
              [ "t:OperatingIncome", "CurrentYearDuration_NonConsolidatedMember" ] => 50,
              # 連結の値は読まない
              [ "t:Assets", "CurrentYearInstant" ] => 1, [ "t:Sga", "CurrentYearDuration" ] => 1 }
    errors = { [ "t:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 1.to_d }
    amounts = described_class.amounts(mapping, source: source_with(facts, errors: errors), consolidation: :non_consolidated)
    aggregate_failures do
      expect(amounts.to_h).to eq("bs.assets" => 900, "pl.operating_profit" => 50, "bs.assets_begin" => 800)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1.to_d, "pl.operating_profit" => nil, "bs.assets_begin" => nil)
    end
  end

  it "すべての科目を評価してから、補正ルールを一覧の順に、同じ対応表・XBRL・連結区分で適用する" do
    calls = []
    rules = %w[first second].map do |name|
      Module.new do
        define_singleton_method(:apply) do |amounts, mapping:, source:, consolidation:|
          calls << [ name, amounts.keys, mapping, source, consolidation ]
          amounts.store("pl.#{name}", 1, nil)
        end
      end
    end
    stub_const("Ingestion::Adjustments::ALL", rules)
    mapping = mapping_of([ "bs.assets", :instant, "t:Assets" ], [ "pl.revenue", :duration, "t:Sales" ])
    source = source_with({ [ "t:Assets", "CurrentYearInstant" ] => 900, [ "t:Sales", "CurrentYearDuration" ] => 300 })

    amounts = described_class.amounts(mapping, source: source, consolidation: :consolidated)
    aggregate_failures do
      expect(calls).to eq [ [ "first", %w[bs.assets pl.revenue], mapping, source, :consolidated ],
                            [ "second", %w[bs.assets pl.revenue pl.first], mapping, source, :consolidated ] ]
      expect(amounts.keys).to eq %w[bs.assets pl.revenue pl.first pl.second]
    end
  end

  it "補正ルールは、期首現金 → CF残高 → 売上候補 → 売上0 の順に適用する" do
    expect(Ingestion::Adjustments::ALL).to eq [ Ingestion::Adjustments::OpeningCash, Ingestion::Adjustments::CashFlowStatementBalance,
                                                Ingestion::Adjustments::RevenueCandidate, Ingestion::Adjustments::ZeroRevenue ]
  end

  describe "#extract" do
    include SyntheticXbrl

    # 形式判定の代役。受けた引数を記録し、連結区分の接尾辞ごとに決めた形式を返す
    let(:detector_calls) { [] }

    def detector(formats)
      calls = detector_calls
      Class.new do
        define_method(:detect) do |xbrl, accounting_standard:, industry_code:, consolidation:|
          calls << [ xbrl, accounting_standard, industry_code, consolidation ]
          formats.fetch(consolidation)
        end
      end.new
    end

    def extract(dei:, facts:, formats:)
      document = synthetic_xbrl_document(dei: dei, facts: facts)
      parsed = Ingestion::DeiExtractor.new.extract(document)
      @period = document.for_reporting_period(start_date: parsed.fiscal_year_start_date, end_date: parsed.fiscal_year_end_date)
      described_class.new.extract(@period, parsed, detector: detector(formats))
    end

    it "連結を作成する書類は、連結（DEIの会計基準・連結の業種コード）→ 単体（日本基準・単体の業種コード）の順に、区分の形式の対応表で科目を、区分の会計基準で公表ROEを取る" do
      statements = extract(
        dei: { accounting_standard: "IFRS", has_consolidated: "true",
               consolidated_industry_code: "cte", non_consolidated_industry_code: "bnk" },
        facts: { [ "jpigp_cor:AssetsIFRS", "CurrentYearInstant" ] => 300,
                 [ "jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults", "CurrentYearDuration" ] => "0.1",
                 [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
                 [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.05" },
        formats: { "" => "ifrs_classified", "_NonConsolidatedMember" => "jgaap_general" })

      aggregate_failures do
        expect(detector_calls).to eq [ [ @period, "ifrs", "cte", "" ], [ @period, "japan_gaap", "bnk", "_NonConsolidatedMember" ] ]
        expect(statements.map { |data| [ data.consolidation_type, data.accounting_standard, data.presentation_format,
                                         data.amounts.to_h, data.disclosed_roe, data.fiscal_year_end_date ] }).to eq [
          [ :consolidated, "ifrs", "ifrs_classified", { "bs.assets" => 300 }, 0.1.to_d, nil ],
          [ :non_consolidated, "japan_gaap", "jgaap_general", { "bs.assets" => 100 }, 0.05.to_d, nil ]
        ]
        expect(statements).to all(be_a(FinancialStatements::StatementData))
        expect(statements.map(&:amounts)).to all(be_frozen)
      end
    end

    it "連結を作成しない書類は、単体だけを取る" do
      statements = extract(dei: { has_consolidated: "false" },
                           facts: { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 300,
                                    [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100 },
                           formats: { "_NonConsolidatedMember" => "jgaap_general" })

      aggregate_failures do
        expect(detector_calls.map(&:last)).to eq [ "_NonConsolidatedMember" ]
        expect(statements.map { |data| [ data.consolidation_type, data.amounts.to_h ] })
          .to eq [ [ :non_consolidated, { "bs.assets" => 100 } ] ]
      end
    end

    it "形式に対応表がない区分（unsupported）は、科目を空にし、公表ROEは区分の会計基準で取る" do
      statements = extract(
        dei: { has_consolidated: "false" },
        facts: { [ "jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember" ] => 100,
                 [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.05" },
        formats: { "_NonConsolidatedMember" => "unsupported" })

      expect(statements.map { |data| [ data.presentation_format, data.amounts.to_h, data.amounts.rounding_errors, data.disclosed_roe ] })
        .to eq [ [ "unsupported", {}, {}, 0.05.to_d ] ]
    end
  end
end
