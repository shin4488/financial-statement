require "rails_helper"

RSpec.describe "指標用の期首・期末データの抽出" do
  [ Ingestion::Extractors::JgaapGeneral, Ingestion::Extractors::JgaapBank,
    Ingestion::Extractors::JgaapInsurance ].each do |extractor|
    it "#{extractor.name}は新株予約権・非支配持分を含めず、区分ごとに自己資本を取る" do
      facts = {}
      { "Prior1YearInstant" => [ 300, 50, 500 ], "CurrentYearInstant" => [ 400, -20, 600 ] }.each do |context, values|
        facts[[ "jppfs_cor:ShareholdersEquity", context ]] = values[0]
        facts[[ "jppfs_cor:ValuationAndTranslationAdjustments", context ]] = values[1]
        facts[[ "jppfs_cor:NetAssets", context ]] = values[2]
      end
      facts[[ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant_NonConsolidatedMember" ]] = 10
      facts[[ "jppfs_cor:NetAssets", "CurrentYearInstant_NonConsolidatedMember" ]] = 10
      xbrl = synthetic_xbrl_document(facts: facts)
      expect(extractor.new(xbrl, "").extract).to include(
        "bs.equity_attributable_to_owners" => 380, "bs.equity_attributable_to_owners_begin" => 350)
      standalone = extractor.new(xbrl, "_NonConsolidatedMember").extract
      expect(standalone["bs.equity_attributable_to_owners"]).to eq 10
      expect(standalone).not_to have_key("bs.equity_attributable_to_owners_begin")
    end
  end

  it "調整項目がない場合、純資産との一致を確認できない値を自己資本にしない" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 100,
      [ "jppfs_cor:NetAssets", "CurrentYearInstant" ] => 120,
      [ "jppfs_cor:ValuationAndTranslationAdjustments", "Prior1YearInstant" ] => 20
    })
    items = Ingestion::Extractors::JgaapGeneral.new(xbrl, "").extract
    expect(items).not_to have_key("bs.equity_attributable_to_owners")
    expect(items).not_to have_key("bs.equity_attributable_to_owners_begin")
  end

  it "銀行の会員勘定合計も自己資本の基礎とし、残高0を欠損にしない" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jppfs_cor:ShareholdersEquityShinkinBNK", "Prior1YearInstant" ] => 300,
      [ "jppfs_cor:ValuationAndTranslationAdjustments", "Prior1YearInstant" ] => -50,
      [ "jppfs_cor:ShareholdersEquityShinkinBNK", "CurrentYearInstant" ] => 0,
      [ "jppfs_cor:NetAssets", "CurrentYearInstant" ] => 0
    })
    expect(Ingestion::Extractors::JgaapBank.new(xbrl, "").extract).to include(
      "bs.equity_attributable_to_owners_begin" => 250, "bs.equity_attributable_to_owners" => 0)
  end

  it "信金中央金庫の実XBRLで会員勘定と評価差額から連結・単体の自己資本を取る" do
    xbrl = load_xbrl_fixture("S100YRHX")
    expect(Ingestion::Extractors::JgaapBank.new(xbrl, "").extract).to include(
      "bs.equity_attributable_to_owners_begin" => 1_498_222_000_000,
      "bs.equity_attributable_to_owners" => 1_622_898_000_000)
    expect(Ingestion::Extractors::JgaapBank.new(xbrl, "_NonConsolidatedMember").extract).to include(
      "bs.equity_attributable_to_owners_begin" => 1_455_165_000_000,
      "bs.equity_attributable_to_owners" => 1_581_127_000_000)
  end

  it "その他の包括利益累計額のタグも評価・換算差額等と同じ位置で使う" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 100,
      [ "jppfs_cor:AccumulatedOtherComprehensiveIncome", "CurrentYearInstant" ] => -20
    })
    expect(Ingestion::Extractors::JgaapGeneral.new(xbrl, "").extract["bs.equity_attributable_to_owners"]).to eq 80
  end

  it "純資産の差が開示精度を超える場合は、調整差額0と推測しない" do
    xbrl = instance_double(Xbrl::Document)
    facts = { "jppfs_cor:ShareholdersEquity" => 100_000,
              "jppfs_cor:SubscriptionRightsToShares" => 10_000,
              "jppfs_cor:NetAssets" => 113_000 }
    allow(xbrl).to receive(:money) { |tag, _context| facts[tag] }
    allow(xbrl).to receive(:rounding_error).and_return(1_000.to_d)
    expect(Ingestion::Extractors::JgaapOwnersEquity.new.evaluate(xbrl, "CurrentYearInstant")).to be_nil
  end

  it "開示精度不明の差額も丸め誤差扱いで埋めない" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 100,
      [ "jppfs_cor:SubscriptionRightsToShares", "CurrentYearInstant" ] => 10,
      [ "jppfs_cor:NetAssets", "CurrentYearInstant" ] => 111
    })
    expect(Ingestion::Extractors::JgaapOwnersEquity.new.evaluate(xbrl, "CurrentYearInstant")).to be_nil
  end

  it "ガス事業の合計タグがなくても、内訳と附帯事業収益を合算し、総額との併記は重複させない" do
    facts = {
      [ "jppfs_cor:GasSalesGAS", "CurrentYearDuration" ] => 100,
      [ "jppfs_cor:ThirdPartyAccessRevenueGAS", "CurrentYearDuration" ] => 5,
      [ "jppfs_cor:RevenueFromInteroperatorSettlementGAS", "CurrentYearDuration" ] => 10,
      [ "jppfs_cor:MiscellaneousOperatingRevenueGAS", "CurrentYearDuration" ] => 20,
      [ "jppfs_cor:RevenueForIncidentalBusinessesGAS", "CurrentYearDuration" ] => 30
    }
    [ nil, 115 ].each do |total|
      facts[[ "jppfs_cor:SalesFromGasBusinessGAS", "CurrentYearDuration" ]] = total
      items = Ingestion::Extractors::JgaapGeneral.new(synthetic_xbrl_document(facts: facts), "").extract
      expect(items["pl.revenue"]).to eq 165
    end
  end

  it "実XBRLの日本基準連結から期首・期末の自己資本を取る" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100XTDX"), "").extract
    expect(items).to include(
      "bs.assets_begin" => 170_202_000_000, "bs.assets" => 195_873_000_000,
      "bs.equity_attributable_to_owners_begin" => 118_112_000_000,
      "bs.equity_attributable_to_owners" => 131_294_000_000)
  end

  it "実XBRLのIFRSから期首・期末の親会社所有者帰属持分を取る" do
    items = Ingestion::Extractors::IfrsClassified.new(load_xbrl_fixture("S100YB5L"), "").extract
    expect(items).to include(
      "bs.assets_begin" => 14_248_344_000_000, "bs.assets" => 15_511_506_000_000,
      "bs.equity_attributable_to_owners_begin" => 6_935_084_000_000,
      "bs.equity_attributable_to_owners" => 7_429_441_000_000)
  end

  it "調整差額0・新株予約権ありの単体でも、純資産の内訳と開示精度を検算して自己資本を取る" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100YR8L"), "_NonConsolidatedMember").extract
    expect(items).to include(
      "bs.equity_attributable_to_owners_begin" => 748_162_000,
      "bs.equity_attributable_to_owners" => 825_018_000)
  end

  it "株式引受権と新株予約権を自己資本に混ぜず、評価差額0の単体も取得する" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100YCL0"), "_NonConsolidatedMember").extract
    expect(items).to include(
      "bs.equity_attributable_to_owners_begin" => 407_400_000_000,
      "bs.equity_attributable_to_owners" => 350_255_000_000)
  end

  it "ガス事業だけでなく雑収益・附帯事業を含む全社売上を使う" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100XTDX"), "_NonConsolidatedMember").extract
    expect(items["pl.revenue"]).to eq 155_516_000_000
  end

  it "本表・サマリとも企業拡張タグの単体収益を、連結値で代用しない" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100YB25"), "_NonConsolidatedMember").extract
    expect(items["pl.revenue"]).to be_nil
  end

  it "一部事業が企業拡張タグでも標準サマリの全社売上で純利益率・回転率を求める" do
    items = Ingestion::Extractors::JgaapGeneral.new(load_xbrl_fixture("S100YGFN"), "_NonConsolidatedMember").extract
    # 飯野海運: 海運104,979百万円 + 不動産11,909百万円。総額は標準サマリにも開示される。
    expect(items["pl.revenue"]).to eq 116_888_000_000
    metrics = FinancialStatements::Indicators.build(instance_double(Disclosure::FinancialStatement,
                                                                    items_hash: items, consolidated?: false))
    expect(metrics[:net_profit_margin].value).to be_within(1e-12).of(12_756.0 / 116_888)
    expect(metrics[:asset_turnover].value).to be_within(1e-12).of(116_888.0 / ((228_116 + 243_418) / 2.0))
  end
end
