require "rails_helper"

RSpec.describe Charts::Segments do
  describe ".segment" do
    it "高さは絶対値、表示する金額と比率は符号付きの値にする" do
      expect(described_class.segment("loss", "損失", -31, "loss", base: 1_000))
        .to have_attributes(key: "loss", label: "損失", amount: 31, signed_amount: -31, ratio: -3.1,
                            color_role: "loss", tooltip_label: nil)
    end

    it "signedを渡すと、高さは金額の絶対値のまま、表示する金額と比率はsignedにする" do
      expect(described_class.segment("equity", "純資産", 300, "equity", base: 1_000, signed: -300))
        .to have_attributes(amount: 300, signed_amount: -300, ratio: -30.0)
    end

    it "比率は小数1桁に切り捨て、2進数の誤差を含めない" do
      aggregate_failures do
        expect(described_class.segment("a", "a", 2, "asset1", base: 3).ratio).to eq 66.6
        expect(described_class.segment("a", "a", -2, "loss", base: 3).ratio).to eq(-66.6)
        expect(described_class.segment("a", "a", 199, "asset1", base: 1_000).ratio).to eq 19.9
      end
    end

    it "分母がないか0なら、比率を出さない" do
      expect(described_class.segment("spacer", "", 500, "spacer", base: nil).ratio).to be_nil
      expect(described_class.segment("a", "a", 500, "asset1", base: 0).ratio).to be_nil
    end

    it "ツールチップの表示名を渡せる" do
      expect(described_class.segment("opex", "営業費用", 10, "expense1", base: 100, tooltip: "営業費用（原価を含む）").tooltip_label)
        .to eq "営業費用（原価を含む）"
    end
  end
end
