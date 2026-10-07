require "rails_helper"

RSpec.describe FinancialStatements::CashFlowVerification do
  # 千円単位で開示した金額（端数の上限は1千円）
  def amounts(values)
    FinancialStatements::Amounts.new.tap do |result|
      values.each do |code, amount|
        result[code] = amount
        result.rounding_errors[code] = 1_000.to_d
      end
    end
  end

  # ぷらっとホーム 2021年3月期（単体）: 財務活動がなく、財務CFの行がない
  let(:without_financing) do
    { "cf.cash_begin" => 334_170_000, "cf.operating" => -12_047_000, "cf.investing" => -3_400_000,
      "cf.exchange_effect" => 55_000, "cf.cash_end" => 318_777_000 }
  end

  describe ".amounts" do
    it "行がない項目を0とみなして、換算差額も含めた式が端数の範囲で成り立てば0にする" do
      expect(described_class.amounts(amounts(without_financing))).to eq(
        "cf.cash_begin" => 334_170_000, "cf.operating" => -12_047_000, "cf.investing" => -3_400_000,
        "cf.financing" => 0, "cf.cash_end" => 318_777_000)
    end

    it "合併による増加も式に含める" do
      # visumo 2026年3月期: 財務CFの行がなく、合併による増加23,354千円がある
      values = { "cf.cash_begin" => 347_308_000, "cf.operating" => 155_130_000, "cf.investing" => -219_133_000,
                 "cf.merger" => 23_354_000, "cf.cash_end" => 306_659_000 }
      expect(described_class.amounts(amounts(values))["cf.financing"]).to eq 0
    end

    it "式が成り立たなければ、行がない項目はnilのまま（実際には0でないおそれがある）" do
      values = without_financing.merge("cf.cash_end" => 300_000_000)
      expect(described_class.amounts(amounts(values))["cf.financing"]).to be_nil
    end

    it "期末残がなければ、ほかの項目を0にしない（CF計算書そのものがない）" do
      expect(described_class.amounts(amounts({})).values).to all(be_nil)
    end

    it "5点がそろっていれば、式が合わなくても開示どおりの値を返す" do
      values = without_financing.merge("cf.financing" => 1_000_000)
      expect(described_class.amounts(amounts(values))["cf.financing"]).to eq 1_000_000
    end
  end

  describe ".mismatch" do
    it "式が成り立てばnil" do
      expect(described_class.mismatch(amounts(without_financing))).to be_nil
    end

    it "行がない項目を0とみなしても式が成り立たなければ、式に使った金額を返す" do
      values = without_financing.merge("cf.cash_end" => 300_000_000)
      expect(described_class.mismatch(amounts(values))).to eq(values)
    end

    it "期末残がなければ照合しない" do
      expect(described_class.mismatch(amounts(without_financing.except("cf.cash_end")))).to be_nil
    end

    it "精度の分からない金額は、差が0のときだけ成り立つとみなす" do
      # 差は1千円（各金額の千円未満の端数）。精度が分かれば端数の範囲に収まる
      aggregate_failures do
        expect(described_class.mismatch(amounts(without_financing))).to be_nil
        expect(described_class.mismatch(without_financing)).to eq without_financing
        expect(described_class.mismatch(without_financing.merge("cf.cash_end" => 318_778_000))).to be_nil
      end
    end
  end
end
