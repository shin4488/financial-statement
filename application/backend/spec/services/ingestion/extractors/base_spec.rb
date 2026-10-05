require "rails_helper"

# マッピング表の記法（単一タグ / フォールバック / 合算 sum / 最大値 max）の評価規則を、
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
        "pl.revenue" => [ "t:IndustryTotal", max("t:OperatingRevenue", sum("t:NetSales", "t:OperatingIncome2")),
                          "jpcrp_cor:NetSalesSummaryOfBusinessResults", "filer_ext:BusinessRevenues" ],
        "pl.sga" => sum("t:Selling", "t:Administrative", distinct_amounts: true),
        "pl.summary_revenue" => [ "t:SummaryRevenue", filer_ext(/RevenueSummaryOfBusinessResults\z/) ],
        "pl.operating_profit" => "t:OperatingIncome"
      }.freeze)
    end
  end

  # facts: { [qname, context] => 値 } のスタブ。blanks: 値が空（表では「－」）のタグの [qname, context]
  def extract_with(facts, errors: {}, filer_names: [], blanks: [])
    xbrl = instance_double(Xbrl::Document)
    allow(xbrl).to receive(:element_names).with("filer_ext").and_return(Set.new(filer_names))
    allow(xbrl).to receive(:rounding_error) { |qname, ctx| errors[[ qname, ctx ]] }
    allow(xbrl).to receive(:money) { |qname, ctx| facts[[ qname, ctx ]] }
    allow(xbrl).to receive(:text) { |qname, ctx| blanks.include?([ qname, ctx ]) ? "" : facts[[ qname, ctx ]]&.to_s }
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

  describe "最大値（総額候補が併記されるとき最も包括的な値を採る）" do
    it "営業収益が総額（売上高+営業収入 と一致）なら営業収益" do
      facts = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 1_000, [ "t:NetSales", "CurrentYearDuration" ] => 900,
                [ "t:OperatingIncome2", "CurrentYearDuration" ] => 100 }
      expect(extract_with(facts)["pl.revenue"]).to eq 1_000
    end

    it "売上高が総額で営業収益が一部の事業だけなら売上高" do
      facts = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 200, [ "t:NetSales", "CurrentYearDuration" ] => 3_500 }
      expect(extract_with(facts)["pl.revenue"]).to eq 3_500
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

  describe "同じ金額のタグを1回だけ数える合算" do
    it "2つのタグに同じ金額が付いていれば、足さずに1つ分とする" do
      facts = { [ "t:Selling", "CurrentYearDuration" ] => 500, [ "t:Administrative", "CurrentYearDuration" ] => 500 }
      errors = { [ "t:Selling", "CurrentYearDuration" ] => 1.to_d, [ "t:Administrative", "CurrentYearDuration" ] => 1.to_d }
      amounts = extract_with(facts, errors: errors)
      expect(amounts["pl.sga"]).to eq 500
      expect(amounts.rounding_errors["pl.sga"]).to eq 1
    end

    it "金額が違えば合算する" do
      facts = { [ "t:Selling", "CurrentYearDuration" ] => 500, [ "t:Administrative", "CurrentYearDuration" ] => 300 }
      expect(extract_with(facts)["pl.sga"]).to eq 800
    end
  end

  describe "要素名の形で探す企業拡張タグ" do
    let(:context) { "CurrentYearDuration" }

    it "前の候補がなければ、要素名の形が合う企業拡張タグの金額と精度を使う" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:BusinessRevenues", context ] => 615 }
      errors = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 1.to_d }
      amounts = extract_with(facts, errors: errors, filer_names: %w[BusinessRevenueSummaryOfBusinessResults BusinessRevenues])
      expect(amounts["pl.summary_revenue"]).to eq 615
      expect(amounts.rounding_errors["pl.summary_revenue"]).to eq 1
    end

    it "前の候補（標準タグ）が取れれば企業拡張タグは使わない" do
      facts = { [ "t:SummaryRevenue", context ] => 900, [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615 }
      expect(extract_with(facts, filer_names: %w[BusinessRevenueSummaryOfBusinessResults])["pl.summary_revenue"]).to eq 900
    end

    it "形が合う要素が複数あっても、金額が同じなら1つとして取る" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:OperatingRevenueSummaryOfBusinessResults", context ] => 615 }
      names = %w[BusinessRevenueSummaryOfBusinessResults OperatingRevenueSummaryOfBusinessResults]
      expect(extract_with(facts, filer_names: names)["pl.summary_revenue"]).to eq 615
    end

    it "形が合う要素の金額が食い違えば、どれが目的の科目か決められないため取らない" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:OperatingRevenueSummaryOfBusinessResults", context ] => 251 }
      names = %w[BusinessRevenueSummaryOfBusinessResults OperatingRevenueSummaryOfBusinessResults]
      expect(extract_with(facts, filer_names: names)).not_to have_key("pl.summary_revenue")
    end
  end

  describe "経営指標の要約の売上と合わない売上の差し替え" do
    let(:context) { "CurrentYearDuration" }
    # 売上高が製品売上高だけで、合計の事業収益は企業拡張タグに付いている書類
    let(:facts) { { [ "t:NetSales", context ] => 107, [ "t:SummaryRevenue", context ] => 615 } }

    it "売上の取得候補のうち要約の売上と一致するものを売上にし、その精度を使う" do
      errors = { [ "filer_ext:BusinessRevenues", context ] => 1.to_d }
      amounts = extract_with(facts.merge([ "filer_ext:BusinessRevenues", context ] => 615), errors: errors)
      expect(amounts["pl.revenue"]).to eq 615
      expect(amounts.rounding_errors["pl.revenue"]).to eq 1
    end

    it "要約と一致する候補がなければ売上を変えない" do
      expect(extract_with(facts.merge([ "filer_ext:BusinessRevenues", context ] => 508))["pl.revenue"]).to eq 107
    end

    it "経営指標の要約のタグは照合の相手なので、要約と同じ金額でも売上にしない" do
      amounts = extract_with(facts.merge([ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ] => 615))
      expect(amounts["pl.revenue"]).to eq 107
    end

    it "売上が要約の売上と端数の範囲で一致していれば、要約と同じ金額の候補があっても変えない" do
      facts = { [ "t:IndustryTotal", context ] => 614, [ "t:SummaryRevenue", context ] => 615,
                [ "filer_ext:BusinessRevenues", context ] => 615 }
      errors = { [ "t:IndustryTotal", context ] => 1.to_d, [ "t:SummaryRevenue", context ] => 1.to_d }
      expect(extract_with(facts, errors: errors)["pl.revenue"]).to eq 614
    end
  end

  describe "売上0（売上の行が「－」）" do
    let(:context) { "CurrentYearDuration" }
    let(:operating_loss) { { [ "t:OperatingIncome", context ] => -4_271 } }

    it "本表の売上の行と要約の売上がどちらも空なら、売上0と確かめられたとして両方に0を保存する" do
      amounts = extract_with(operating_loss, blanks: [ [ "t:NetSales", context ], [ "t:SummaryRevenue", context ] ])
      aggregate_failures do
        expect(amounts.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
        expect(amounts.rounding_errors.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
      end
    end

    it "要約の売上の行がなければ、売上が一覧にない要素名で開示されているおそれがあるため保存しない" do
      expect(extract_with(operating_loss, blanks: [ [ "t:NetSales", context ] ])).not_to have_key("pl.revenue")
    end

    it "要約に売上の値があれば保存しない" do
      amounts = extract_with(operating_loss.merge([ "t:SummaryRevenue", context ] => 615), blanks: [ [ "t:NetSales", context ] ])
      expect(amounts).not_to have_key("pl.revenue")
    end

    it "要約の売上だけが空なら保存しない" do
      expect(extract_with(operating_loss, blanks: [ [ "t:SummaryRevenue", context ] ])).not_to have_key("pl.revenue")
    end

    it "要約のタグ（jpcrp_cor）が売上の取得候補にあっても、本表の売上の行とはみなさない" do
      blanks = [ [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ], [ "t:SummaryRevenue", context ] ]
      expect(extract_with(operating_loss, blanks: blanks)).not_to have_key("pl.revenue")
    end

    it "損益の値がなければ（連結初年度で連結の損益計算書を作っていない書類など）、売上の行が空でも保存しない" do
      blanks = [ [ "t:NetSales", context ], [ "t:SummaryRevenue", context ], [ "t:OperatingIncome", context ] ]
      expect(extract_with({}, blanks: blanks)).not_to have_key("pl.revenue")
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

  it "採用した最大候補の精度を保持し、候補の金額を変更しない" do
    facts = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 200, [ "t:NetSales", "CurrentYearDuration" ] => 3_500 }
    errors = { [ "t:OperatingRevenue", "CurrentYearDuration" ] => 1.to_d, [ "t:NetSales", "CurrentYearDuration" ] => 10.to_d }
    amounts = extract_with(facts, errors: errors)
    expect(amounts["pl.revenue"]).to eq 3_500
    expect(amounts.rounding_errors["pl.revenue"]).to eq 10
  end
end
