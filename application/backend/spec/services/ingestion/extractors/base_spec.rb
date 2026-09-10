require "rails_helper"

# マッピング表の4記法（単一タグ / フォールバック / 合算 sum / 一致候補 consistent）の評価規則を、
# 実XBRLに依存しない最小のExtractorで検証する
RSpec.describe Ingestion::Extractors::Base do
  let(:extractor_class) do
    # ブロック内の定数代入はレキシカルスコープ（このspec）に定義されてしまうため const_set で無名クラスに定義する
    Class.new(described_class) do
      const_set(:INSTANT_MAPPING, {
        "bs.assets" => "t:Assets",
        "bs.equity" => [ "t:EquityTotal", sum("t:EquityA", "t:EquityB") ],
        "cf.cash_end" => "t:Cash"
      }.freeze)
      const_set(:DURATION_MAPPING, {
        "pl.revenue" => [ "t:IndustryTotal", consistent("t:OperatingRevenue", sum("t:NetSales", "t:OperatingIncome2")) ]
      }.freeze)
    end
  end

  # facts: { [qname, context] => 値 } のスタブ
  def extract_with(facts, errors: {})
    xbrl = instance_double(Xbrl::Document)
    allow(xbrl).to receive(:rounding_error) { |qname, ctx| errors[[ qname, ctx ]] }
    allow(xbrl).to receive(:money) { |qname, ctx| facts[[ qname, ctx ]] }
    extractor_class.new(xbrl, "").extract
  end

  it "単一タグは値をそのまま、無ければキー自体を作らない" do
    expect(extract_with({ [ "t:Assets", "CurrentYearInstant" ] => 100 })).to eq("bs.assets" => 100)
  end

  it "フォールバックは先に取れた値を採用し、合算は存在するタグだけを足す（1つも無ければ「開示なし」）" do
    aggregate_failures do
      expect(extract_with({ [ "t:EquityTotal", "CurrentYearInstant" ] => 50, [ "t:EquityA", "CurrentYearInstant" ] => 999 })["bs.equity"]).to eq 50
      expect(extract_with({ [ "t:EquityA", "CurrentYearInstant" ] => 30, [ "t:EquityB", "CurrentYearInstant" ] => 20 })["bs.equity"]).to eq 50
      expect(extract_with({ [ "t:EquityB", "CurrentYearInstant" ] => 20 })["bs.equity"]).to eq 20
      expect(extract_with({})).not_to have_key("bs.equity")
    end
  end

  describe "総額候補の検算" do
    it "営業収益が総額（売上高+営業収入 と一致）なら営業収益" do
      facts = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 1_000, [ "t:NetSales", "CurrentYearDuration" ] => 900,
                [ "t:OperatingIncome2", "CurrentYearDuration" ] => 100 }
      expect(extract_with(facts)["pl.revenue"]).to eq 1_000
    end

    it "総額か内訳かが不明な候補の食い違いを大小で決めない" do
      facts = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 200, [ "t:NetSales", "CurrentYearDuration" ] => 3_500 }
      expect(extract_with(facts)).not_to have_key("pl.revenue")
    end

    it "総額タグがなく売上高と営業収入だけなら合算、営業収入だけの持株会社なら営業収入" do
      aggregate_failures do
        expect(extract_with({ [ "t:NetSales", "CurrentYearDuration" ] => 896, [ "t:OperatingIncome2", "CurrentYearDuration" ] => 28 })["pl.revenue"]).to eq 924
        expect(extract_with({ [ "t:OperatingIncome2", "CurrentYearDuration" ] => 585 })["pl.revenue"]).to eq 585
      end
    end

    it "フォールバックの前段（業種固有の総額）があればそちらを優先する" do
      facts = { [ "t:IndustryTotal", "CurrentYearDuration" ] => 382, [ "t:NetSales", "CurrentYearDuration" ] => 295 }
      expect(extract_with(facts)["pl.revenue"]).to eq 382
    end
  end

  describe "CF期首残高の導出" do
    it "期末残高（cf.cash_end）と同じタグを前期末（Prior1YearInstant）から引く" do
      facts = { [ "t:Cash", "CurrentYearInstant" ] => 120, [ "t:Cash", "Prior1YearInstant" ] => 100 }
      expect(extract_with(facts)).to include("cf.cash_end" => 120, "cf.cash_begin" => 100)
    end

    it "前期末の値が無ければcf.cash_beginのキー自体を作らない" do
      expect(extract_with({ [ "t:Cash", "CurrentYearInstant" ] => 120 })).not_to have_key("cf.cash_begin")
    end
  end
  it "合算の丸め精度は入力の和、未知が混ざれば未知のまま保存する" do
    facts = { [ "t:EquityA", "CurrentYearInstant" ] => 30, [ "t:EquityB", "CurrentYearInstant" ] => 20 }
    errors = { [ "t:EquityA", "CurrentYearInstant" ] => 1.to_d, [ "t:EquityB", "CurrentYearInstant" ] => 10.to_d }
    expect(extract_with(facts, errors: errors).rounding_errors["bs.equity"]).to eq 11
    expect(extract_with(facts, errors: errors.except([ "t:EquityB", "CurrentYearInstant" ])).rounding_errors["bs.equity"]).to be_nil
  end

  it "最大の候補ではなく、開示された構成科目と一致する候補を選ぶ" do
    xbrl = instance_double(Xbrl::Document)
    values = { "t:A" => 200, "t:B" => 100, "t:C" => 60, "t:D" => 40 }
    allow(xbrl).to receive(:money) { |qname, _| values[qname] }
    allow(xbrl).to receive(:rounding_error) { |qname, _| qname == "t:B" ? 1.to_d : 10.to_d }
    spec = described_class.consistent("t:A", "t:B", components: [ "t:C", "t:D" ])
    expect(spec.evaluate(xbrl, "ctx")).to eq 100
    expect(spec.rounding_error(xbrl, "ctx")).to eq 1
  end
end
