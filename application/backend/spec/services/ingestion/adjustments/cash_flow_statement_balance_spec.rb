require "rails_helper"

RSpec.describe Ingestion::Adjustments::CashFlowStatementBalance do
  # 期末残の取得候補だけを持つ対応表。先頭は財政状態計算書の現金のタグ、次に要約のタグ、最後にCF計算書の残高のタグ
  let(:mapping) do
    Ingestion::Mappings::Mapping.define("test") { item "cf.cash_end", [ "jppfs_cor:BsCash", "jpcrp_cor:CashSummary", "jppfs_cor:CfCash" ] }
  end

  # 期首800＋営業300−投資100−財務50＝950。期末残は財政状態計算書の現金の1,000で、CFの式が成り立たない
  def extracted(except: nil)
    FinancialStatements::Amounts.new.tap do |amounts|
      { "cf.cash_begin" => 800, "cf.operating" => 300, "cf.investing" => -100, "cf.financing" => -50, "cf.cash_end" => 1_000 }
        .except(except).each { |code, amount| amounts.store(code, amount, 1.to_d) }
    end
  end

  # facts: { [qname, 標準のコンテキストID] => 値 } を書いたXBRL。decimals は開示の精度（"-1"なら端数の上限は10、"-2"なら100）
  def source_with(facts, decimals: {}) = synthetic_xbrl_document(facts: facts, decimals: decimals)

  def apply(amounts, source)
    described_class.apply(amounts, mapping: mapping, source: source, consolidation: :consolidated)
    amounts
  end

  it "2番目以降の本表の候補でCFの式が成り立てば、期首残・期末残をその候補の金額と端数にする" do
    source = source_with({ [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => 950, [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => 800 },
                         decimals: { [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => "-1", [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => "-1" })
    amounts = apply(extracted, source)
    aggregate_failures do
      expect(amounts.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 800, 950 ]
      expect(amounts.rounding_errors.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 10.to_d, 10.to_d ]
    end
  end

  it "候補でもCFの式が成り立たなければ、金額も端数も変えない" do
    source = source_with({ [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => 900, [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => 800 },
                         decimals: { [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => "-1" })
    amounts = apply(extracted, source)
    aggregate_failures do
      expect(amounts.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 800, 1_000 ]
      expect(amounts.rounding_errors.values_at("cf.cash_begin", "cf.cash_end")).to eq [ 1.to_d, 1.to_d ]
    end
  end

  # 試算は端数を比べない。端数だけが広い候補で、CFの式を成り立たせない
  it "候補の金額が期首残・期末残と同じなら、端数を広げればCFの式が成り立つときも、端数を変えない" do
    source = source_with({ [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => 1_000, [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => 800 },
                         decimals: { [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => "-2", [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => "-2" })
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
    source = source_with({ [ "jppfs_cor:CfCash", "CurrentYearInstant" ] => 950, [ "jppfs_cor:CfCash", "Prior1YearInstant" ] => 800 })
    expect(apply(extracted(except: "cf.cash_end"), source).to_h).not_to have_key("cf.cash_end")
  end
end
