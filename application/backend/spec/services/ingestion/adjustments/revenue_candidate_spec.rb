require "rails_helper"

RSpec.describe Ingestion::Adjustments::RevenueCandidate do
  let(:context) { "CurrentYearDuration" }

  # 売上の通常の取得候補（売上高・要約の売上高・企業拡張タグの事業収益）と、差し替えのときだけ使う候補（売上高と賃貸収入の合計）を持つ対応表
  let(:mapping) do
    Ingestion::Mappings::Mapping.define("test") do
      item "pl.revenue", [ "t:NetSales", "jpcrp_cor:NetSalesSummaryOfBusinessResults", "filer_ext:BusinessRevenues" ],
           replacements: [ sum("t:NetSales", "t:Rent", all_present: true) ]
      item "pl.summary_revenue", "t:SummaryRevenue"
    end
  end

  # facts・errors: { [qname, 標準のコンテキストID] => 値 }
  def source_with(facts, errors: {})
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, queried| facts[[ qname, queried ]] }
      allow(xbrl).to receive(:rounding_error) { |qname, queried| errors[[ qname, queried ]] }
      allow(xbrl).to receive(:element_names).and_return(Set.new)
      allow(xbrl).to receive(:text).and_return(nil)
    end
  end

  def extract(source) = Ingestion::StatementExtractor.amounts(mapping, source: source, consolidation: :consolidated)

  it "通常の取得候補で要約の売上と合わなければ、差し替えのときだけ使う候補を試し、一致すればその金額と端数にする" do
    facts = { [ "t:NetSales", context ] => 300, [ "t:Rent", context ] => 8, [ "t:SummaryRevenue", context ] => 308,
              [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ] => 308 }
    errors = { [ "t:NetSales", context ] => 1.to_d, [ "t:Rent", context ] => 1.to_d }
    amounts = extract(source_with(facts, errors: errors))
    aggregate_failures do
      expect(amounts["pl.revenue"]).to eq 308
      expect(amounts.rounding_errors["pl.revenue"]).to eq 2.to_d
    end
  end

  it "通常の取得候補（要約のタグを除く）に要約の売上と一致するものがあれば、差し替えのときだけ使う候補より先に使う" do
    facts = { [ "t:NetSales", context ] => 300, [ "t:Rent", context ] => 8, [ "t:SummaryRevenue", context ] => 308,
              [ "filer_ext:BusinessRevenues", context ] => 308 }
    source = source_with(facts, errors: { [ "filer_ext:BusinessRevenues", context ] => 1.to_d })
    amounts = extract(source)
    aggregate_failures do
      expect(amounts["pl.revenue"]).to eq 308
      expect(amounts.rounding_errors["pl.revenue"]).to eq 1.to_d
      expect(source).not_to have_received(:money).with("t:Rent", anything)
    end
  end

  it "売上が要約の売上と一致すれば、差し替えのときだけ使う候補を評価しない" do
    source = source_with({ [ "t:NetSales", context ] => 308, [ "t:Rent", context ] => 8, [ "t:SummaryRevenue", context ] => 308 })
    expect(extract(source)["pl.revenue"]).to eq 308
    expect(source).not_to have_received(:money).with("t:Rent", anything)
  end

  it "差し替えのときだけ使う候補でも要約の売上と合わなければ、売上を変えない" do
    facts = { [ "t:NetSales", context ] => 300, [ "t:Rent", context ] => 5, [ "t:SummaryRevenue", context ] => 308 }
    expect(extract(source_with(facts))["pl.revenue"]).to eq 300
  end
end
