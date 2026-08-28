require "rails_helper"

# 貸借2本を描くBS Builderは共通基盤（two_sided_chart）の上の宣言なので、
# 「正常系 / 債務超過 / 貸借乖離」の3観点を形式ごとに検証する
RSpec.describe "Charts::Builders BS各種" do
  describe Charts::Builders::BsIfrsSummary do
    it "科目によらず理由の説明つきで表示不可になる" do
      chart = described_class.new({}).build
      expect(chart.renderable).to be false
      expect(chart.note).to include "詳細データが収録されていない"
    end
  end

  describe Charts::Builders::BsJgaapGeneral do
    let(:items) do
      { "bs.current_assets" => 400, "bs.tangible_fixed_assets" => 300,
        "bs.intangible_fixed_assets" => 100, "bs.investments_and_other_assets" => 200,
        "bs.current_liabilities" => 350, "bs.non_current_liabilities" => 250,
        "bs.equity" => 400 }
    end

    it "借方4段・貸方3段で、比率の分母は表示科目の合計になる" do
      chart = described_class.new(items).build
      expect(chart.renderable).to be true
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[currentAssets tangible intangible investments]
      expect(credit.segments.map(&:key)).to eq %w[currentLiabilities fixedLiabilities equity]
      expect(debit.segments.map(&:ratio).sum).to eq 100.0
    end

    it "債務超過では3本目バーにspacer + マイナス資本が入る" do
      chart = described_class.new(items.merge(
        "bs.equity" => -100, "bs.current_liabilities" => 700, "bs.non_current_liabilities" => 400)).build
      expect(chart.bars.size).to eq 3
      spacer, equity = chart.bars.last.segments
      expect(spacer.color_role).to eq "spacer"
      expect(spacer.ratio).to be_nil
      expect(spacer.amount).to eq 1_000 # 負債1100 - |資本100| = 資産合計
      expect(equity.color_role).to eq "equity" # 債務超過でも色は変えず負値で伝える
      expect(equity.signed_amount).to eq(-100)
    end

    it "貸借が1割超乖離したらunrenderable" do
      chart = described_class.new(items.merge("bs.current_assets" => 4_000)).build
      expect(chart.renderable).to be false
    end

    describe "固定資産の3分類を持たない業種（電気・鉄道・電気通信の単体など）" do
      # 東京電力HD連結（単位: 百万円）: 有形/無形の標準タグがなく、投資その他の資産だけが取れる
      let(:utility_items) do
        { "bs.current_assets" => 2_349_796, "bs.investments_and_other_assets" => 4_110_656,
          "bs.non_current_assets" => 13_225_805,
          "bs.current_liabilities" => 4_684_165, "bs.non_current_liabilities" => 7_473_085,
          "bs.equity" => 3_418_351 }
      end

      it "内訳の合計が固定資産に合わないときは固定資産合計の1段で描く" do
        chart = described_class.new(utility_items).build
        expect(chart.renderable).to be true
        debit, = chart.bars
        expect(debit.segments.map(&:key)).to eq %w[currentAssets fixedAssets]
        expect(debit.segments.last.amount).to eq 13_225_805
      end

      it "内訳の合計が固定資産に合う一般事業会社は内訳のまま（無形固定資産を開示しない企業も残り2つで合えば内訳）" do
        # 無形100を除き、固定資産合計=有形300+投資その他200、負債側も100減らして貸借を合わせる
        chart = described_class.new(items.except("bs.intangible_fixed_assets")
                                         .merge("bs.non_current_assets" => 500, "bs.current_liabilities" => 250)).build
        expect(chart.bars.first.segments.map(&:key)).to eq %w[currentAssets tangible investments]
      end
    end
  end

  describe Charts::Builders::BsJgaapInsurance do
    # かんぽ生命連結（単位: 百万円）
    let(:items) do
      { "bs.assets" => 58_442_160, "bs.cash_and_equivalents" => 1_752_984,
        "bs.securities" => 44_931_286, "bs.loans" => 2_134_764,
        "bs.policy_reserves" => 48_102_350, "bs.liabilities" => 54_288_531,
        "bs.equity" => 4_153_628 }
    end

    it "借方[現金及び預貯金, 有価証券, 貸付金, その他資産] / 貸方[保険契約準備金, その他負債, 純資産] で残差が導出される" do
      chart = described_class.new(items).build
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[cash securities loans otherAssets]
      expect(credit.segments.map(&:key)).to eq %w[policyReserves otherLiabilities equity]
      expect(debit.segments.last.amount).to eq 58_442_160 - 1_752_984 - 44_931_286 - 2_134_764
      expect(credit.segments[1].amount).to eq 54_288_531 - 48_102_350
      expect(credit.segments.sum(&:amount)).to be_within(1).of(debit.segments.sum(&:amount)) # 開示値の百万円丸め
    end

    it "保険契約準備金が欠けるとunrenderable（負債全額をその他負債として描くと誤ったグラフになるため）" do
      chart = described_class.new(items.except("bs.policy_reserves")).build
      expect(chart.renderable).to be false
    end
  end

  describe Charts::Builders::BsIfrsClassified do
    let(:items) do
      { "bs.current_assets" => 3_090_503, "bs.non_current_assets" => 12_421_004,
        "bs.assets" => 15_511_506, "bs.current_liabilities" => 2_832_074,
        "bs.non_current_liabilities" => 5_248_784, "bs.equity" => 7_430_649 }
    end

    it "借方2段・貸方3段で貸借一致する（単位: 百万円）" do
      chart = described_class.new(items).build
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[currentAssets nonCurrentAssets]
      expect(credit.segments.map(&:key)).to eq %w[currentLiabilities nonCurrentLiabilities equity]
      expect(credit.segments.sum(&:amount)).to eq debit.segments.sum(&:amount)
    end
  end

  describe Charts::Builders::BsIfrsLiquidity do
    let(:items) do
      { "bs.assets" => 28_804_400, "bs.cash_and_equivalents" => 7_034_795,
        "bs.liabilities" => 27_450_168, "bs.equity" => 1_354_232 }
    end

    it "現金とその他資産（導出）の2段になる" do
      chart = described_class.new(items).build
      debit, = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[cash otherAssets]
      expect(debit.segments.last.amount).to eq 28_804_400 - 7_034_795
    end

    it "現金が欠けるとその他資産が導出できずunrenderable" do
      chart = described_class.new(items.except("bs.cash_and_equivalents")).build
      expect(chart.renderable).to be false
    end
  end

  describe Charts::Builders::BsJgaapBank do
    let(:items) do
      { "bs.assets" => 431_731_548, "bs.cash_and_equivalents" => 90_045_500,
        "bs.loans" => 133_799_490, "bs.securities" => 85_714_795,
        "bs.deposits" => 239_439_246, "bs.liabilities" => 407_987_396,
        "bs.equity" => 23_744_152 }
    end

    it "その他資産・その他負債が残差で導出される（単位: 百万円）" do
      chart = described_class.new(items).build
      debit, credit = chart.bars
      other_assets = debit.segments.find { |s| s.key == "otherAssets" }
      other_liabilities = credit.segments.find { |s| s.key == "otherLiabilities" }
      expect(other_assets.amount).to eq 122_171_763
      expect(other_liabilities.amount).to eq 168_548_150
      expect(credit.segments.sum(&:amount)).to eq debit.segments.sum(&:amount)
    end

    it "預金が欠けるとunrenderable（負債全額をその他負債として描くと預金0%の誤ったグラフになるため）" do
      chart = described_class.new(items.except("bs.deposits")).build
      expect(chart.renderable).to be false
    end
  end
end
