require "rails_helper"

RSpec.describe "BSの開示値による構成と検算" do
  let(:items) do
    { "bs.assets" => 1_000, "bs.liabilities" => 600, "bs.equity" => 400,
     "bs.current_assets" => 400, "bs.non_current_assets" => 600,
     "bs.tangible_fixed_assets" => 300, "bs.intangible_fixed_assets" => 100,
     "bs.investments_and_other_assets" => 200,
     "bs.current_liabilities" => 350, "bs.non_current_liabilities" => 250 }
  end

  [ Charts::Builders::BsJgaapGeneral, Charts::Builders::BsIfrsClassified,
   Charts::Builders::BsJgaapBank, Charts::Builders::BsJgaapInsurance,
   Charts::Builders::BsIfrsLiquidity ].each do |builder|
    it "#{builder}: 合計を検算し、総資産に対する比率を返す" do
      chart = builder.new(items).build
      expect(chart.renderable).to be true
      expect(chart.bars.first.segments.sum(&:amount)).to eq 1_000
      expect(chart.bars.last.segments.sum(&:amount)).to eq 1_000
      expect(chart.bars.last.segments.last.ratio).to eq 40.0
      expect(chart.bars.flat_map(&:segments).map(&:key)).not_to include("otherAssets", "otherLiabilities")
    end

    it "#{builder}: 1%の不一致も精度の根拠なしには許容しない" do
      expect(builder.new(items.merge("bs.equity" => 410)).build.renderable).to be false
    end

    it "#{builder}: 合計欠損を内訳や差額で補わない" do
      %w[bs.assets bs.liabilities bs.equity].each do |code|
        expect(builder.new(items.except(code)).build.renderable).to be false
      end
    end

    it "#{builder}: 債務超過の実値・比率を負で保持する" do
      chart = builder.new(items.merge("bs.liabilities" => 1_100, "bs.equity" => -100)).build
      expect(chart.bars.size).to eq 3
      spacer, equity = chart.bars.last.segments
      expect(spacer.amount).to eq 1_000
      expect(spacer.ratio).to be_nil
      expect(equity.signed_amount).to eq(-100)
      expect(equity.ratio).to eq(-10)
    end
  end

  it "固定資産の3分類が揃えば内訳を使う" do
    chart = Charts::Builders::BsJgaapGeneral.new(items).build
    expect(chart.bars.first.segments.map(&:key)).to eq %w[currentAssets tangible intangible investments]
  end

  it "固定資産内訳が欠けた場合は固定資産合計へ戻す" do
    chart = Charts::Builders::BsJgaapGeneral.new(items.except("bs.intangible_fixed_assets")).build
    expect(chart.bars.first.segments.map(&:key)).to eq %w[currentAssets fixedAssets]
  end

  it "繰延資産など未収録科目がある場合は総資産を表示し分母を縮めない" do
    chart = Charts::Builders::BsJgaapGeneral.new(items.merge("bs.assets" => 1_100, "bs.equity" => 500)).build
    expect(chart.bars.first.segments.map(&:key)).to eq [ "assets" ]
    expect(chart.bars.last.segments.last.ratio).to eq 45.4
  end

  it "負の資産内訳を絶対値で水増しして表示しない" do
    chart = Charts::Builders::BsIfrsClassified.new(items.merge("bs.current_assets" => -100, "bs.non_current_assets" => 1_100)).build
    expect(chart.renderable).to be false
  end

  it "詳細タグのないIFRSのBSは理由付きで表示しない" do
    chart = Charts::Builders::BsIfrsSummary.new({}).build
    expect(chart.renderable).to be false
    expect(chart.note).to include("詳細データ")
  end
end
