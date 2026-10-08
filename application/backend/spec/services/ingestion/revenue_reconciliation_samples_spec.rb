require "rails_helper"

# 売上と経営指標の要約の売上の照合を、実XBRLの取込（公開API）で確かめる。
# 売上が要約と合わないときは要約と一致する売上の取得候補に差し替え、それでも合わないものだけを警告で知らせる
RSpec.describe "売上と経営指標の要約の照合（実XBRL）" do
  let(:warnings) { [] }

  before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

  def ingest(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
    Disclosure::FinancialStatement.find_by!(is_primary: true).items_hash
  end

  it "スリー・ディー・マトリックス 2017年4月期: 売上高が製品売上高だけのため、要約の事業収益と一致する事業収益に差し替え、警告しない" do
    items = ingest("S100B9WP")
    aggregate_failures do
      expect(items["pl.revenue"]).to eq 615_852_000
      expect(items["pl.summary_revenue"]).to eq 615_852_000
      expect(warnings).to be_empty
    end
  end

  describe "売上高の下に営業収入の内訳を並べ、営業収益の合計の行がない会社は、要約と一致する両方の合計に差し替える" do
    {
      "S100Y3VC" => [ "セキチュー 2026年2月期（不動産賃貸収入 848,235千円）", 31_867_169_000 ],
      "S100YD39" => [ "アルビス 2026年3月期（不動産賃貸収入 1,101百万円）", 100_951_000_000 ],
      "S100Y5IT" => [ "リンガーハット 2026年2月期（その他の営業収入 819,558千円）", 45_084_680_000 ]
    }.each do |doc_id, (name, revenue)|
      it "#{name}: 売上を売上高と営業収入の内訳の合計にし、PLも左右が合うため警告しない" do
        items = ingest(doc_id)
        aggregate_failures do
          expect(items["pl.revenue"]).to eq revenue
          expect(warnings).to be_empty
        end
      end
    end
  end

  describe "IFRSで標準タグの収益にその他の収益などを含める会社は、要約と一致する営業収益の企業拡張タグに差し替える" do
    {
      "S100YA84" => [ "日本取引所グループ 2026年3月期（収益計 199,051百万円、営業収益 OperatingRevenueRevenue2IFRS）", 198_735_000_000 ],
      "S100YM8I" => [ "マネックスグループ 2026年3月期（収益合計 92,787百万円、営業収益 OperatingRevenueRevenueIFRS）", 83_606_000_000 ]
    }.each do |doc_id, (name, revenue)|
      it "#{name}: 売上を営業収益にし、警告しない" do
        items = ingest(doc_id)
        aggregate_failures do
          expect(items["pl.revenue"]).to eq revenue
          expect(warnings).to be_empty
        end
      end
    end
  end

  it "ミニストップ 2026年2月期: 売上を営業総収入で取り、要約の営業総収入と一致するため警告しない" do
    items = ingest("S100Y4UH")
    aggregate_failures do
      expect(items["pl.revenue"]).to eq 91_788_000_000
      expect(warnings).to be_empty
    end
  end

  it "ベルク: 売上（売上高＋営業収入）から営業収入を除いた額が、要約の売上高と一致するため警告しない" do
    items = ingest("S100O4KK")
    aggregate_failures do
      expect(items.values_at("pl.revenue", "pl.non_sales_operating_revenue", "pl.summary_revenue"))
        .to eq [ 300_267_000_000, 3_248_000_000, 297_019_000_000 ]
      expect(warnings).to be_empty
    end
  end

  it "丸井グループ: 要約の売上収益（RevenueKeyFinancialData）と売上が一致するため警告しない" do
    items = ingest("S100YWE4")
    aggregate_failures do
      expect(items["pl.summary_revenue"]).to eq 276_862_000_000
      expect(warnings).to be_empty
    end
  end

  {
    "S100YK5Y" => "大運（売上高と営業収入に同じ金額）",
    "S100YQ6Y" => "イオン（営業収益）",
    "S100XVWE" => "KDDI（IFRS）",
    "S100SO41" => "クリエイト・レストランツHD（IFRSの要約形式）"
  }.each do |doc_id, name|
    it "#{name}: 売上が要約の売上と一致し、警告しない" do
      items = ingest(doc_id)
      aggregate_failures do
        expect(items["pl.summary_revenue"]).to be_present
        expect(warnings).to be_empty
      end
    end
  end
end
