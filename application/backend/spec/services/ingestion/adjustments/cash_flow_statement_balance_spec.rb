require "rails_helper"

RSpec.describe Ingestion::Adjustments::CashFlowStatementBalance do
  # 期末残の取得候補だけを持つ対応表。先頭は財政状態計算書の現金のタグ、次に要約のタグ、最後にCF計算書の残高のタグ
  def mapping_with(candidates)
    expression = Ingestion::Expressions.wrap(candidates)
    double("mapping").tap { |mapping| allow(mapping).to receive(:expression) { |code| expression if code == "cf.cash_end" } }
  end

  let(:mapping) { mapping_with([ "t:BsCash", "jpcrp_cor:CashSummary", "t:CfCash" ]) }

  # 期首800＋営業300−投資100−財務50＝950。期末残は財政状態計算書の現金の1,000で、CFの式が成り立たない
  def extracted(except: nil)
    FinancialStatements::Amounts.new.tap do |amounts|
      { "cf.cash_begin" => 800, "cf.operating" => 300, "cf.investing" => -100, "cf.financing" => -50, "cf.cash_end" => 1_000 }
        .except(except).each { |code, amount| amounts.store(code, amount, 1.to_d) }
    end
  end

  # facts・errors: { [qname, 標準のコンテキストID] => 値 }
  def source_with(facts, errors: {})
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, context| facts[[ qname, context ]] }
      allow(xbrl).to receive(:rounding_error) { |qname, context| errors[[ qname, context ]] }
    end
  end

  def apply(amounts, source, mapping: self.mapping)
    described_class.apply(amounts, mapping: mapping, source: source, consolidation: :consolidated)
    amounts
  end

  it "2番目以降の本表の候補でCFの式が成り立てば、期首残・期末残をその候補の金額と端数にする" do
    source = source_with({ [ "t:CfCash", "CurrentYearInstant" ] => 950, [ "t:CfCash", "Prior1YearInstant" ] => 800 },
                         errors: { [ "t:CfCash", "CurrentYearInstant" ] => 10.to_d, [ "t:CfCash", "Prior1YearInstant" ] => 10.to_d })
    amounts = apply(extracted, source)
    aggregate_failures do
      expect(amounts.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 800, 950 ]
      expect(amounts.rounding_errors.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 10.to_d, 10.to_d ]
    end
  end

  it "候補でもCFの式が成り立たなければ、金額も端数も変えない" do
    source = source_with({ [ "t:CfCash", "CurrentYearInstant" ] => 900, [ "t:CfCash", "Prior1YearInstant" ] => 800 },
                         errors: { [ "t:CfCash", "CurrentYearInstant" ] => 10.to_d })
    amounts = apply(extracted, source)
    aggregate_failures do
      expect(amounts.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 800, 1_000 ]
      expect(amounts.rounding_errors.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 1.to_d, 1.to_d ]
    end
  end

  it "経営指標の要約のタグは本表の残高ではないため、CFの式が成り立っても使わない" do
    source = source_with({ [ "jpcrp_cor:CashSummary", "CurrentYearInstant" ] => 950 })
    expect(apply(extracted, source)["cf.cash_end"]).to eq 1_000
  end

  it "期末残を取れていなければ差し替えない" do
    source = source_with({ [ "t:CfCash", "CurrentYearInstant" ] => 950, [ "t:CfCash", "Prior1YearInstant" ] => 800 })
    expect(apply(extracted(except: "cf.cash_end"), source).to_h).not_to have_key("cf.cash_end")
  end
end
