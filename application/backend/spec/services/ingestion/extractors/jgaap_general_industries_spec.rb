require "rails_helper"

# 業種別の勘定科目を持つ業種が jgaap_general のフォールバックで抽出できることの実測検証。
# 期待値は各社の有報XBRLの実測値（spec/fixtures/xbrl/README.md）。単位: 円
RSpec.describe Ingestion::Extractors::JgaapGeneral do
  def extract(doc_id, consolidation)
    described_class.new(load_xbrl_fixture(doc_id), consolidation).extract
  end
  let(:consolidated) { Ingestion::Extractors::Base::CONSOLIDATED }
  let(:non_consolidated) { Ingestion::Extractors::Base::NON_CONSOLIDATED }

  describe "電気（S100YIHR 東京電力HD・連結）" do
    subject(:items) { extract("S100YIHR", consolidated) }

    it "営業収益と一括の営業費用（OperatingExpensesELE）を抽出し、原価・販管費は持たない" do
      expect(items).to include("pl.revenue" => 6_328_574_000_000,
                               "pl.operating_expenses" => 5_990_884_000_000,
                               "pl.operating_profit" => 337_689_000_000)
      expect(items).not_to include("pl.cost_of_sales", "pl.sga")
    end

    it "固定資産は合計と投資その他の資産だけが取れる（有形/無形の標準タグは電気事業の様式にない）" do
      expect(items).to include("bs.non_current_assets" => 13_225_805_000_000,
                               "bs.investments_and_other_assets" => 4_110_656_000_000)
      expect(items).not_to include("bs.tangible_fixed_assets", "bs.intangible_fixed_assets")
    end
  end

  describe "鉄道" do
    it "単体（S100YC7N JR東日本）: 鉄道事業+関連事業の合算で営業収益・営業費を求め、全事業営業利益を営業利益とする" do
      items = extract("S100YC7N", non_consolidated)
      expect(items).to include("pl.revenue" => 2_020_442_000_000 + 205_293_000_000,
                               "pl.operating_expenses" => 1_795_414_000_000 + 128_314_000_000,
                               "pl.operating_profit" => 302_007_000_000) # OperatingIncomeTotalBusiness
    end

    it "連結（S100YE63 東急）: 営業費の内訳（運輸業等営業費及び売上原価・販管費）と一括の営業費の両方を保存する" do
      items = extract("S100YE63", consolidated)
      expect(items).to include("pl.revenue" => 1_086_179_000_000,
                               "pl.cost_of_sales" => 744_710_000_000, # OperatingExpensesAndCostOfSalesOfTransportationRWY
                               "pl.sga" => 238_275_000_000,
                               "pl.operating_expenses" => 982_986_000_000, # OperatingExpensesRWY
                               "pl.operating_profit" => 103_193_000_000)
    end

    it "単体（S100YE63 東急）: 営業収益（OperatingRevenueRWY）と営業原価・販管費で取れる" do
      items = extract("S100YE63", non_consolidated)
      expect(items).to include("pl.revenue" => 257_120_000_000, "pl.cost_of_sales" => 200_024_000_000,
                               "pl.sga" => 21_594_000_000, "pl.operating_profit" => 35_502_000_000)
    end
  end

  describe "証券（S100YANQ いちよし証券・連結）" do
    it "営業収益・金融費用・販管費を抽出する（営業収益−金融費用−販管費=営業利益）" do
      items = extract("S100YANQ", consolidated)
      expect(items).to include("pl.revenue" => 24_579_000_000, "pl.financial_expenses" => 71_000_000,
                               "pl.sga" => 18_347_000_000, "pl.operating_profit" => 6_160_000_000)
      expect(items).not_to include("pl.cost_of_sales")
    end
  end

  describe "特定金融（S100YI2V アサックス・連結）" do
    it "一括の営業費用（OperatingExpensesSPF）を抽出する。内訳として併記される売上原価も保存される" do
      items = extract("S100YI2V", consolidated)
      expect(items).to include("pl.revenue" => 8_779_361_000, "pl.operating_expenses" => 2_959_600_000,
                               "pl.cost_of_sales" => 272_978_000, "pl.operating_profit" => 5_819_760_000)
    end
  end

  describe "電気通信（S100Y9T5 沖縄セルラー電話・連結）" do
    it "電気通信事業+附帯事業の合算で営業収益・営業費用を求める" do
      items = extract("S100Y9T5", consolidated)
      expect(items).to include("pl.revenue" => 52_291_000_000 + 34_057_000_000,
                               "pl.operating_expenses" => 33_482_000_000 + 34_172_000_000,
                               "pl.operating_profit" => 18_693_000_000)
    end
  end

  describe "海運（S100Y90D 玉井商船）" do
    it "連結: 営業収益と、海運業費用+その他事業費用の合算（原価）・一般管理費（販管費）を抽出する" do
      items = extract("S100Y90D", consolidated)
      expect(items).to include("pl.revenue" => 5_122_027_000,
                               "pl.cost_of_sales" => 3_895_247_000 + 34_863_000,
                               "pl.sga" => 534_138_000, # GeneralAndAdministrativeExpensesWAT
                               "pl.operating_profit" => 657_778_000)
    end

    it "単体: 営業収益の合計タグがなく、海運業収益+その他事業収益の合算になる" do
      items = extract("S100Y90D", non_consolidated)
      expect(items).to include("pl.revenue" => 4_935_674_000 + 4_080_000,
                               "pl.cost_of_sales" => 4_032_427_000 + 1_872_000,
                               "pl.sga" => 487_142_000, "pl.operating_profit" => 418_311_000)
    end
  end

  describe "ガス（S100XTDX 静岡ガス）" do
    it "連結: 売上高・売上原価と供給販売費及び一般管理費（SellingGeneralAndAdministrativeExpensesGAS）" do
      items = extract("S100XTDX", consolidated)
      expect(items).to include("pl.revenue" => 201_207_000_000, "pl.cost_of_sales" => 156_060_000_000,
                               "pl.sga" => 31_074_000_000, "pl.operating_profit" => 14_072_000_000)
    end

    it "単体: 売上高はガス事業売上高（SalesFromGasBusinessGAS）で開示される" do
      items = extract("S100XTDX", non_consolidated)
      expect(items).to include("pl.revenue" => 147_318_000_000, "pl.cost_of_sales" => 118_689_000_000,
                               "pl.sga" => 21_773_000_000, "pl.operating_profit" => 7_277_000_000)
    end
  end

  describe "商品先物（S100YJB4 小林洋行）" do
    it "連結: 売上原価と、その控除後の営業費用（OperatingExpensesCMD）を抽出する" do
      items = extract("S100YJB4", consolidated)
      expect(items).to include("pl.revenue" => 5_047_625_000, "pl.cost_of_sales" => 1_654_880_000,
                               "pl.operating_expenses" => 3_210_396_000, "pl.operating_profit" => 182_347_000)
      expect(items).not_to include("pl.sga")
    end

    it "単体: 商品売上高（NetSales）でなく営業収益（OperatingRevenueCMD）をトップラインにする" do
      items = extract("S100YJB4", non_consolidated)
      expect(items["pl.revenue"]).to eq 382_009_000 # NetSalesは295,575千円
    end
  end

  describe "建設（S100YDJC 大成建設・連結）" do
    it "売上高（完成工事高+開発事業等売上高の合計）と売上原価・販管費で取れる" do
      items = extract("S100YDJC", consolidated)
      expect(items).to include("pl.revenue" => 2_089_091_000_000, "pl.cost_of_sales" => 1_759_035_000_000,
                               "pl.sga" => 142_081_000_000, "pl.operating_profit" => 187_973_000_000)
    end
  end

  describe "営業収益−営業費用型の一般事業会社（S100Y0DB Mマート・単体）" do
    it "汎用の営業費用タグ（OperatingExpenses）を一括の営業費用として抽出する" do
      items = extract("S100Y0DB", non_consolidated)
      expect(items).to include("pl.revenue" => 1_363_651_000, "pl.operating_expenses" => 731_149_000,
                               "pl.operating_profit" => 632_501_000)
    end
  end
end
