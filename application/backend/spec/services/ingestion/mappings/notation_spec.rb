require "rails_helper"

# 対応表の記法（単一タグ / フォールバック / 合算 sum / 最大値 max）の評価規則を、
# 実XBRLに依存しない最小の対応表で検証する
RSpec.describe "対応表の記法と補正ルールの評価" do
  # 科目の期間は科目カタログで決まる（bs.assets・bs.equity・cf.cash_end は当期末、pl.* は当期）
  let(:mapping) do
    Ingestion::Mappings::Mapping.define("test") do
      item "bs.assets", "jppfs_cor:Assets"
      item "bs.equity", [ "jppfs_cor:EquityTotal", sum("jppfs_cor:EquityA", "jppfs_cor:EquityB") ]
      item "cf.cash_end", "jppfs_cor:Cash"
      item "pl.revenue", [ "jppfs_cor:IndustryTotal", max("jppfs_cor:OperatingRevenue", sum("jppfs_cor:NetSales", "jppfs_cor:OperatingIncome2")),
                           "jpcrp_cor:NetSalesSummaryOfBusinessResults", "filer_ext:BusinessRevenues" ]
      item "pl.sga", sum("jppfs_cor:Selling", "jppfs_cor:Administrative", distinct_amounts: true)
      item "pl.summary_revenue", [ "jppfs_cor:SummaryRevenue", filer_ext(/RevenueSummaryOfBusinessResults\z/) ]
      item "pl.operating_profit", "jppfs_cor:OperatingIncome"
    end
  end

  # facts: { [qname, context] => 値 } を書いたXBRLから抽出する。decimals は開示の精度（"0"なら端数の上限は1、"-1"なら10）。
  # blanks: 行はあるが値が空（表では「－」）のタグの [qname, context]
  def extract_with(facts, decimals: {}, blanks: [], mapping: self.mapping)
    xbrl = synthetic_xbrl_document(facts: facts.merge(blanks.to_h { |key| [ key, "" ] }), decimals: decimals)
    Ingestion::StatementExtractor.amounts(mapping, source: xbrl, consolidation: :consolidated)
  end

  it "単一タグは値をそのまま、無ければキー自体を作らない" do
    expect(extract_with({ [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 }).to_h).to eq("bs.assets" => 100)
  end

  it "フォールバックは先に取れた値を採用し、合算は存在するタグだけを足す（1つも無ければ「開示なし」）" do
    aggregate_failures do
      expect(extract_with({ [ "jppfs_cor:EquityTotal", "CurrentYearInstant" ] => 50, [ "jppfs_cor:EquityA", "CurrentYearInstant" ] => 999 })["bs.equity"]).to eq 50
      expect(extract_with({ [ "jppfs_cor:EquityA", "CurrentYearInstant" ] => 30, [ "jppfs_cor:EquityB", "CurrentYearInstant" ] => 20 })["bs.equity"]).to eq 50
      expect(extract_with({ [ "jppfs_cor:EquityB", "CurrentYearInstant" ] => 20 })["bs.equity"]).to eq 20
      expect(extract_with({}).to_h).not_to have_key("bs.equity")
    end
  end

  describe "最大値（総額の候補が併記されるとき、最も大きい値を総額として採る）" do
    it "営業収益が総額（売上高+営業収入 と一致）なら営業収益" do
      facts = { [ "jppfs_cor:OperatingRevenue", "CurrentYearDuration" ] => 1_000, [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 900,
                [ "jppfs_cor:OperatingIncome2", "CurrentYearDuration" ] => 100 }
      expect(extract_with(facts)["pl.revenue"]).to eq 1_000
    end

    it "売上高が総額で営業収益が一部の事業だけなら売上高" do
      facts = { [ "jppfs_cor:OperatingRevenue", "CurrentYearDuration" ] => 200, [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 3_500 }
      expect(extract_with(facts)["pl.revenue"]).to eq 3_500
    end

    it "総額タグがなく売上高と営業収入だけなら合算、営業収入だけの持株会社なら営業収入" do
      aggregate_failures do
        expect(extract_with({ [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 896, [ "jppfs_cor:OperatingIncome2", "CurrentYearDuration" ] => 28 })["pl.revenue"]).to eq 924
        expect(extract_with({ [ "jppfs_cor:OperatingIncome2", "CurrentYearDuration" ] => 585 })["pl.revenue"]).to eq 585
      end
    end

    it "フォールバックの前段（業種固有の総額）があればそちらを優先する" do
      facts = { [ "jppfs_cor:IndustryTotal", "CurrentYearDuration" ] => 382, [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 295 }
      expect(extract_with(facts)["pl.revenue"]).to eq 382
    end
  end

  describe "同じ金額のタグを1回だけ数える合算" do
    it "2つのタグに同じ金額が付いていれば、足さずに1つ分とする" do
      facts = { [ "jppfs_cor:Selling", "CurrentYearDuration" ] => 500, [ "jppfs_cor:Administrative", "CurrentYearDuration" ] => 500 }
      decimals = { [ "jppfs_cor:Selling", "CurrentYearDuration" ] => "0", [ "jppfs_cor:Administrative", "CurrentYearDuration" ] => "0" }
      amounts = extract_with(facts, decimals: decimals)
      expect(amounts["pl.sga"]).to eq 500
      expect(amounts.rounding_errors["pl.sga"]).to eq 1
    end

    it "金額が違えば合算する" do
      facts = { [ "jppfs_cor:Selling", "CurrentYearDuration" ] => 500, [ "jppfs_cor:Administrative", "CurrentYearDuration" ] => 300 }
      expect(extract_with(facts)["pl.sga"]).to eq 800
    end
  end

  describe "要素名の形で探す企業拡張タグ" do
    let(:context) { "CurrentYearDuration" }

    it "前の候補がなければ、要素名の形が合う企業拡張タグの金額と精度を使う" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:BusinessRevenues", context ] => 615 }
      decimals = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => "0" }
      amounts = extract_with(facts, decimals: decimals)
      expect(amounts["pl.summary_revenue"]).to eq 615
      expect(amounts.rounding_errors["pl.summary_revenue"]).to eq 1
    end

    it "前の候補（標準タグ）が取れれば企業拡張タグは使わない" do
      facts = { [ "jppfs_cor:SummaryRevenue", context ] => 900, [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615 }
      expect(extract_with(facts)["pl.summary_revenue"]).to eq 900
    end

    it "形が合う要素が複数あっても、金額が同じなら1つとして取る" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:OperatingRevenueSummaryOfBusinessResults", context ] => 615 }
      names = %w[BusinessRevenueSummaryOfBusinessResults OperatingRevenueSummaryOfBusinessResults]
      expect(extract_with(facts)["pl.summary_revenue"]).to eq 615
    end

    it "形が合う要素の金額が食い違えば、どれが目的の科目か決められないため取らない" do
      facts = { [ "filer_ext:BusinessRevenueSummaryOfBusinessResults", context ] => 615,
                [ "filer_ext:OperatingRevenueSummaryOfBusinessResults", context ] => 251 }
      names = %w[BusinessRevenueSummaryOfBusinessResults OperatingRevenueSummaryOfBusinessResults]
      expect(extract_with(facts).to_h).not_to have_key("pl.summary_revenue")
    end
  end

  describe "すべてのタグに値があるときだけ足す合算" do
    let(:context) { "CurrentYearDuration" }
    let(:all_present) do
      Ingestion::Mappings::Mapping.define("test") do
        item "pl.revenue", [ "jppfs_cor:NetSales", sum("jppfs_cor:NetSales", "jppfs_cor:RentIncome", all_present: true) ]
        item "pl.summary_revenue", "jppfs_cor:SummaryRevenue"
        item "pl.sga", sum("jppfs_cor:Selling", "jppfs_cor:Administrative", all_present: true)
      end
    end

    it "すべてのタグに値があれば足し、1つでもなければ合計として使わない" do
      aggregate_failures do
        expect(extract_with({ [ "jppfs_cor:Selling", context ] => 30, [ "jppfs_cor:Administrative", context ] => 20 }, mapping: all_present)["pl.sga"]).to eq 50
        expect(extract_with({ [ "jppfs_cor:Selling", context ] => 30 }, mapping: all_present).to_h).not_to have_key("pl.sga")
      end
    end

    it "売上高が要約の売上と合わず、売上高と内訳の行の合計が要約と一致すれば、その合計に差し替える" do
      facts = { [ "jppfs_cor:NetSales", context ] => 300, [ "jppfs_cor:RentIncome", context ] => 8, [ "jppfs_cor:SummaryRevenue", context ] => 308 }
      expect(extract_with(facts, mapping: all_present)["pl.revenue"]).to eq 308
    end
  end

  describe "経営指標の要約の売上と合わない売上の差し替え" do
    let(:context) { "CurrentYearDuration" }
    # 売上高が製品売上高だけで、合計の事業収益は企業拡張タグに付いている書類
    let(:facts) { { [ "jppfs_cor:NetSales", context ] => 107, [ "jppfs_cor:SummaryRevenue", context ] => 615 } }

    it "売上の取得候補のうち要約の売上と一致するものを売上にし、その精度を使う" do
      decimals = { [ "filer_ext:BusinessRevenues", context ] => "0" }
      amounts = extract_with(facts.merge([ "filer_ext:BusinessRevenues", context ] => 615), decimals: decimals)
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
      facts = { [ "jppfs_cor:IndustryTotal", context ] => 614, [ "jppfs_cor:SummaryRevenue", context ] => 615,
                [ "filer_ext:BusinessRevenues", context ] => 615 }
      decimals = { [ "jppfs_cor:IndustryTotal", context ] => "0", [ "jppfs_cor:SummaryRevenue", context ] => "0" }
      expect(extract_with(facts, decimals: decimals)["pl.revenue"]).to eq 614
    end
  end

  describe "売上0（売上の行が「－」か、行がない）" do
    let(:context) { "CurrentYearDuration" }
    let(:operating_loss) { { [ "jppfs_cor:OperatingIncome", context ] => -4_271 } }

    it "本表の売上の行と要約の売上がどちらも空なら、売上0と確かめられたとして両方に0を保存する" do
      amounts = extract_with(operating_loss, blanks: [ [ "jppfs_cor:NetSales", context ], [ "jppfs_cor:SummaryRevenue", context ] ])
      aggregate_failures do
        expect(amounts.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
        expect(amounts.rounding_errors.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
      end
    end

    it "要約の売上の行がなければ、売上が一覧にない要素名で開示されているおそれがあるため保存しない" do
      expect(extract_with(operating_loss, blanks: [ [ "jppfs_cor:NetSales", context ] ]).to_h).not_to have_key("pl.revenue")
    end

    it "要約に売上の値があれば保存しない" do
      amounts = extract_with(operating_loss.merge([ "jppfs_cor:SummaryRevenue", context ] => 615), blanks: [ [ "jppfs_cor:NetSales", context ] ])
      expect(amounts.to_h).not_to have_key("pl.revenue")
    end

    it "本表に売上の行がなくても（前期も売上がない会社）、要約の売上が空なら、売上0として保存する" do
      amounts = extract_with(operating_loss, blanks: [ [ "jppfs_cor:SummaryRevenue", context ] ])
      expect(amounts.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
    end

    it "売上の取得候補が要約のタグ（jpcrp_cor）だけの形式は、本表で売上がないことを確かめられないため保存しない" do
      summary_only = Ingestion::Mappings::Mapping.define("test") do
        item "pl.revenue", "jpcrp_cor:NetSalesSummaryOfBusinessResults"
        item "pl.summary_revenue", "jppfs_cor:SummaryRevenue"
        item "pl.operating_profit", "jppfs_cor:OperatingIncome"
      end
      blanks = [ [ "jpcrp_cor:NetSalesSummaryOfBusinessResults", context ], [ "jppfs_cor:SummaryRevenue", context ] ]
      expect(extract_with(operating_loss, blanks: blanks, mapping: summary_only).to_h).not_to have_key("pl.revenue")
    end

    it "損益の値がなければ（連結初年度で連結の損益計算書を作っていない書類など）、売上の行が空でも保存しない" do
      blanks = [ [ "jppfs_cor:NetSales", context ], [ "jppfs_cor:SummaryRevenue", context ], [ "jppfs_cor:OperatingIncome", context ] ]
      expect(extract_with({}, blanks: blanks).to_h).not_to have_key("pl.revenue")
    end
  end

  describe "CF期首残高の導出" do
    it "期末残高（cf.cash_end）と同じタグを前期末（Prior1YearInstant）から引く" do
      facts = { [ "jppfs_cor:Cash", "CurrentYearInstant" ] => 120, [ "jppfs_cor:Cash", "Prior1YearInstant" ] => 100 }
      expect(extract_with(facts).to_h).to include("cf.cash_end" => 120, "cf.cash_begin" => 100)
    end

    it "前期末の値が無ければcf.cash_beginのキー自体を作らない" do
      expect(extract_with({ [ "jppfs_cor:Cash", "CurrentYearInstant" ] => 120 }).to_h).not_to have_key("cf.cash_begin")
    end
  end
  it "合算の丸め精度は入力の和、未知が混ざれば未知のまま保存する" do
    facts = { [ "jppfs_cor:EquityA", "CurrentYearInstant" ] => 30, [ "jppfs_cor:EquityB", "CurrentYearInstant" ] => 20 }
    decimals = { [ "jppfs_cor:EquityA", "CurrentYearInstant" ] => "0", [ "jppfs_cor:EquityB", "CurrentYearInstant" ] => "-1" }
    expect(extract_with(facts, decimals: decimals).rounding_errors["bs.equity"]).to eq 11
    expect(extract_with(facts, decimals: decimals.except([ "jppfs_cor:EquityB", "CurrentYearInstant" ])).rounding_errors["bs.equity"]).to be_nil
  end

  it "採用した最大候補の精度を保持し、候補の金額を変更しない" do
    facts = { [ "jppfs_cor:OperatingRevenue", "CurrentYearDuration" ] => 200, [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 3_500 }
    decimals = { [ "jppfs_cor:OperatingRevenue", "CurrentYearDuration" ] => "0", [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => "-1" }
    amounts = extract_with(facts, decimals: decimals)
    expect(amounts["pl.revenue"]).to eq 3_500
    expect(amounts.rounding_errors["pl.revenue"]).to eq 10
  end
end
