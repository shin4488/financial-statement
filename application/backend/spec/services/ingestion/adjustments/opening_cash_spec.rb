require "rails_helper"

RSpec.describe Ingestion::Adjustments::OpeningCash do
  def money(value, decimals: "-3", unit: Xbrl::Fact::JPY)
    Xbrl::Fact.new(value: value.to_s, decimals: decimals, unit: unit)
  end

  # 期末残だけを抽出した金額の表に補正ルールを適用し、補った期首残を返す（補わなければ nil）。
  # XBRLの代役は、期末残・当期増減・連結範囲変更等と、期首より前の時点の残高（opening）に答える
  def supplemented_opening(opening: money(23_236_000), closing: money(36_621_000), change: money(13_385_000), adjustments: [])
    facts = { [ described_class::BALANCE, :instant ] => closing, [ described_class::CHANGE, :duration ] => change }
    described_class::SCOPE_CHANGES.zip(adjustments) { |qname, fact| facts[[ qname, :duration ]] = fact }
    source = instance_double(Xbrl::ReportingPeriod)
    allow(source).to receive(:fact) { |qname, period:, consolidation:| facts[[ qname, period ]] if consolidation == :consolidated }
    allow(source).to receive(:facts_before_period).with(described_class::BALANCE, consolidation: :consolidated).and_return([ opening ])
    amounts = FinancialStatements::Amounts.new
    amounts.store("cf.cash_end", closing.money, closing.rounding_error)
    described_class.apply(amounts, mapping: nil, source: source, consolidation: :consolidated)
    amounts["cf.cash_begin"] if amounts.key?("cf.cash_begin")
  end

  it "同じCFの増減と整合する開示期首額で補う" do
    expect(supplemented_opening).to eq 23_236_000
  end

  it "丸め差のある場合も計算で作った金額でなく開示額で補う" do
    expect(supplemented_opening(opening: money(1_546_456_000), closing: money(1_530_664_000), change: money(-15_791_000)))
      .to eq 1_546_456_000
  end

  it "連結範囲変更の増減を加えて照合する" do
    expect(supplemented_opening(closing: money(37_621_000), adjustments: [ money(1_000_000) ])).to eq 23_236_000
    expect(supplemented_opening(closing: money(37_621_000))).to be_nil
  end

  it "開示精度の上限に達する差や、精度不明の金額を含む差を許容しない" do
    expect(supplemented_opening(closing: money(36_624_000))).to be_nil
    expect(supplemented_opening(opening: money(23_236_000, decimals: nil), closing: money(36_622_000))).to be_nil
  end

  it "不足・不正な数値や通貨の混在から補完しない" do
    expect(supplemented_opening(change: nil)).to be_nil
    expect(supplemented_opening(opening: money("invalid"))).to be_nil
    expect(supplemented_opening(change: money(13_385_000, unit: "USD"))).to be_nil
    expect(supplemented_opening(opening: money(-1))).to be_nil
  end

  it "厳密な0も開示値として扱う" do
    expect(supplemented_opening(opening: money(0, decimals: "INF"), closing: money(10, decimals: "INF"), change: money(10, decimals: "INF")))
      .to eq 0
  end
end
