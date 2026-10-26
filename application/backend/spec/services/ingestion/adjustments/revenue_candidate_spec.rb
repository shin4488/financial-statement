require "rails_helper"

RSpec.describe Ingestion::Adjustments::RevenueCandidate do
  let(:context) { "CurrentYearDuration" }

  # 売上の通常の取得候補（売上高・要約の売上高・企業拡張タグの事業収益）と、差し替えのときだけ使う候補（売上高と賃貸収入の合計）を持つ対応表
  let(:mapping) do
    Ingestion::Mappings::Mapping.define("test") do
      item "pl.revenue", [ "jppfs_cor:NetSales", "jpcrp_cor:NetSalesSummaryOfBusinessResults", "filer_ext:BusinessRevenues" ],
           replacements: [ sum("jppfs_cor:NetSales", "jppfs_cor:Rent", all_present: true) ]
      item "pl.summary_revenue", "jppfs_cor:SummaryRevenue"
    end
  end

  # facts: { [qname, 標準のコンテキストID] => 値 }。decimals は開示の精度（"0"なら端数の上限は1）。書かない金額は精度不明
  def extract(facts, decimals: {})
    source = synthetic_xbrl_document(facts: facts, decimals: decimals)
    Ingestion::StatementExtractor.amounts(mapping, source: source, consolidation: :consolidated)
  end

  it "通常の取得候補で要約の売上と合わなければ、差し替えのときだけ使う候補を試し、一致すればその金額と端数にする" do
    facts = { [ "jppfs_cor:NetSales", context ] => 300, [ "jppfs_cor:Rent", context ] => 8, [ "jppfs_cor:SummaryRevenue", context ] => 308,
              [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ] => 308 }
    amounts = extract(facts, decimals: { [ "jppfs_cor:NetSales", context ] => "0", [ "jppfs_cor:Rent", context ] => "0" })
    aggregate_failures do
      expect(amounts["pl.revenue"]).to eq 308
      expect(amounts.rounding_errors["pl.revenue"]).to eq 2.to_d
    end
  end

  it "通常の取得候補（要約のタグを除く）に要約の売上と一致するものがあれば、差し替えのときだけ使う候補より先に使う" do
    # 差し替えのときだけ使う候補（売上高＋賃貸収入）も308になるが、精度が分からないため、使えば端数は不明になる
    facts = { [ "jppfs_cor:NetSales", context ] => 300, [ "jppfs_cor:Rent", context ] => 8, [ "jppfs_cor:SummaryRevenue", context ] => 308,
              [ "filer_ext:BusinessRevenues", context ] => 308 }
    amounts = extract(facts, decimals: { [ "filer_ext:BusinessRevenues", context ] => "0" })
    aggregate_failures do
      expect(amounts["pl.revenue"]).to eq 308
      expect(amounts.rounding_errors["pl.revenue"]).to eq 1.to_d
    end
  end

  it "売上が要約の売上と一致すれば、差し替えのときだけ使う候補が要約と一致しても、売上の金額と端数を変えない" do
    # 差し替えのときだけ使う候補（売上高＋賃貸収入）も308で、使えば端数は2になる
    facts = { [ "jppfs_cor:NetSales", context ] => 308, [ "jppfs_cor:Rent", context ] => 0, [ "jppfs_cor:SummaryRevenue", context ] => 308 }
    amounts = extract(facts, decimals: facts.keys.to_h { |key| [ key, "0" ] })
    aggregate_failures do
      expect(amounts["pl.revenue"]).to eq 308
      expect(amounts.rounding_errors["pl.revenue"]).to eq 1.to_d
    end
  end

  it "差し替えのときだけ使う候補でも要約の売上と合わなければ、売上を変えない" do
    facts = { [ "jppfs_cor:NetSales", context ] => 300, [ "jppfs_cor:Rent", context ] => 5, [ "jppfs_cor:SummaryRevenue", context ] => 308 }
    expect(extract(facts)["pl.revenue"]).to eq 300
  end
end
