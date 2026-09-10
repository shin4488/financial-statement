require "rails_helper"

RSpec.describe "実XBRLからの財務検算" do
  it "NTTの税引前利益まで実際の金融損益・持分法損益を用いて照合する" do
    xbrl = Xbrl::Document.load(require_xbrl_fixture("S100YCP3"))
    items = Ingestion::Extractors::IfrsClassified.new(xbrl, "").extract
    chart = Charts::Builders::PlIfrs.new(items).build
    expect(chart.renderable).to be true
    expect(items["pl.profit_before_tax"]).to eq 1_581_923_000_000
    expect(chart.bars.first.segments.find { |s| s.key == "financeCosts" }.amount).to eq 240_068_000_000
    expect(chart.bars.flat_map(&:segments).map(&:key)).not_to include("otherNet")
  end

  it "武田薬品の拡張タグにしかない製品関連無形資産償却等を残差で捏造しない" do
    items = Ingestion::Extractors::IfrsClassified.new(Xbrl::Document.load(require_xbrl_fixture("S100YB5L")), "").extract
    expect(items["pl.research_and_development"]).to eq 675_924_000_000
    expect(Charts::Builders::PlIfrs.new(items).build.renderable).to be false
  end

  it "ガス単体の売上に雑営業・附帯事業を含め、対応する費用も積み上げる" do
    items = Ingestion::Extractors::JgaapGeneral.new(Xbrl::Document.load(require_xbrl_fixture("S100XTDX")), "_NonConsolidatedMember").extract
    expect(items["pl.revenue"]).to eq 155_516_000_000
    chart = Charts::Builders::PlJgaapGeneral.new(items).build
    expect(chart.renderable).to be true
    expect(chart.bars.first.segments.map(&:key)).to include("gasMiscellaneous", "gasIncidental")
  end

  it "取込からDB再読込を経てもXBRLの表示精度を保持する" do
    require_xbrl_fixture("S100YD29")
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: "S100YD29", work_dir: dir)
    end
    fs = Disclosure::FinancialStatement.find_by!(consolidation_type: :consolidated)
    expect(fs.items.find_by!(item_code: "bs.assets").rounding_error).to eq 1_000_000
    chart = Charts::BuilderRegistry.build_all(fs.reload)[:balance_sheet]
    expect(chart.renderable).to be true
    expect(chart.bars.first.segments.first.amount).to eq 58_442_160_000_000
  end
end
