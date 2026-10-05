require "rails_helper"

# 売上を企業拡張タグだけで開示する会社の売上を、実XBRLの取込（公開API）で確かめる。
# 期待値は有報の損益計算書の売上の合計。経営指標の要約に売上があれば、それとも一致する
RSpec.describe "売上を企業拡張タグだけで開示する会社（実XBRL）" do
  let(:warnings) { [] }

  before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

  def ingest(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
    Disclosure::FinancialStatement.find_by!(is_primary: true).items_hash
  end

  {
    "S100YRPF" => [ "スカイマーク 2026年3月期（日本基準）", 110_441_000_000 ],
    "S100YF0X" => [ "リボミック 2026年3月期（日本基準）", 3_000_000 ],
    "S100XSQX" => [ "ラクオリア創薬 2025年12月期（日本基準）", 3_979_956_000 ],
    "S100YHXU" => [ "博報堂DYホールディングス 2026年3月期（日本基準）", 861_003_000_000 ],
    "S100J54V" => [ "NTTドコモ 2020年3月期（IFRS）", 4_651_290_000_000 ],
    "S100L2D0" => [ "Jトラスト 2020年12月期（IFRS）", 32_652_000_000 ]
  }.each do |doc_id, (name, revenue)|
    it "#{name}: 売上を取り、要約の売上と一致するため警告しない" do
      items = ingest(doc_id)
      aggregate_failures do
        expect(items["pl.revenue"]).to eq revenue
        expect(items["pl.summary_revenue"]).to eq revenue
        expect(warnings).to be_empty
      end
    end
  end

  it "セーラー広告 2026年3月期: 取扱高（7,858,502千円）ではなく売上（2,224,849千円）を取る" do
    expect(ingest("S100YEAK")["pl.revenue"]).to eq 2_224_849_000
  end

  it "ローソン 2023年2月期（IFRS）: 要約のチェーン全店売上（2,545,463百万円）ではなく、本表の収益を取る" do
    expect(ingest("S100QTB3")["pl.revenue"]).to eq 1_000_385_000_000
  end

  it "トヨタ自動車 2026年3月期（IFRS）: 要約にIFRSの売上がなくても、本表の収益を取る" do
    expect(ingest("S100Y8NY")["pl.revenue"]).to eq 50_684_952_000_000
  end
end
