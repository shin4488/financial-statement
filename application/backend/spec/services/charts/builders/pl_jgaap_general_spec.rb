require "rails_helper"

RSpec.describe Charts::Builders::PlJgaapGeneral do
  describe "黒字" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 300,
        "pl.operating_profit" => 100 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方[原価, 販管費, 営業利益] / 貸方[売上] になる" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
      expect(credit.segments.map(&:key)).to eq %w[revenue]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "営業損失" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 800, "pl.sga" => 400,
        "pl.operating_profit" => -200 }
    end
    subject(:chart) { described_class.new(items).build }

    it "営業損失は貸方に符号付き実値で積まれる" do
      debit, credit = chart.bars
      loss = credit.segments.find { |s| s.key == "operatingLoss" }
      expect(loss.amount).to eq 200
      expect(loss.signed_amount).to eq(-200)
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "原価・販管費がない持株会社型" do
    it "売上と営業利益だけで描画される（開示のない費用科目は積まない）" do
      chart = described_class.new({ "pl.revenue" => 1_000, "pl.operating_profit" => 1_000 }).build
      expect(chart.renderable).to be true
      debit, = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[operatingProfit]
    end
  end

  describe "費用の構成が業種で異なる" do
    it "証券（営業収益−金融費用−販管費=営業利益）は金融費用を原価の位置に積む" do
      chart = described_class.new({ "pl.revenue" => 24_579, "pl.financial_expenses" => 71,
                                    "pl.sga" => 18_347, "pl.operating_profit" => 6_160 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[financialExpenses sga operatingProfit]
    end

    it "営業費用一括型（電気・特定金融など）は営業費用1本で描く" do
      chart = described_class.new({ "pl.revenue" => 6_328_574, "pl.operating_expenses" => 5_990_884,
                                    "pl.operating_profit" => 337_689 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[operatingExpenses operatingProfit]
    end

    it "内訳と一括の営業費用が併記されていれば内訳（原価・販管費）で描く（重複計上しない）" do
      chart = described_class.new({ "pl.revenue" => 1_086_179, "pl.cost_of_sales" => 744_710, "pl.sga" => 238_275,
                                    "pl.operating_expenses" => 982_986, "pl.operating_profit" => 103_193 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
    end

    it "内訳では貸借が合わず一括の営業費用でなら合う企業（原価が営業費用の内訳として併記される特定金融など）は一括で描く" do
      chart = described_class.new({ "pl.revenue" => 8_779, "pl.cost_of_sales" => 272,
                                    "pl.operating_expenses" => 2_959, "pl.operating_profit" => 5_819 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[operatingExpenses operatingProfit]
    end

    it "売上原価と原価控除後の営業費用を開示する商品先物取引業は [原価, 営業費用] で描く（単位: 千円）" do
      chart = described_class.new({ "pl.revenue" => 5_047_625, "pl.cost_of_sales" => 1_654_880,
                                    "pl.operating_expenses" => 3_210_396, "pl.operating_profit" => 182_347 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[costOfSales operatingExpenses operatingProfit]
    end
  end

  it "売上か営業利益が欠ければunrenderable" do
    expect(described_class.new({ "pl.operating_profit" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 0, "pl.operating_profit" => 1 }).build.renderable).to be false
  end

  describe "貸借の1割超乖離" do
    it "原価が科目ゆれで取れていない企業はunrenderable（単位: 円）" do
      chart = described_class.new({
        "pl.revenue" => 2_478_950_000, "pl.sga" => 748_887_000,
        "pl.operating_profit" => 108_348_000 }).build
      expect(chart.renderable).to be false
    end

    it "乖離が1割以内なら描画される" do
      chart = described_class.new({
        "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250,
        "pl.operating_profit" => 100 }).build
      expect(chart.renderable).to be true
    end
  end
end
