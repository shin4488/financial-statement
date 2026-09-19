require "rails_helper"

RSpec.describe FinancialStatements::Indicators do
  let(:items) do
    {
      "pl.profit_attributable_to_owners" => 80, "pl.profit" => 100, "pl.revenue" => 1_000,
      "bs.assets_begin" => 1_000, "bs.assets" => 1_500,
      "bs.equity_attributable_to_owners_begin" => 400, "bs.equity_attributable_to_owners" => 600,
      "bs.equity" => 900
    }
  end
  let(:consolidated) { true }
  subject(:indicators) do
    described_class.build(instance_double(Disclosure::FinancialStatement,
                                         items_hash: items, consolidated?: consolidated))
  end

  it "期首期末平均と親会社帰属利益を使い、丸め前の分解式が一致する" do
    expect(indicators.transform_values(&:value)).to eq(
      roe: 0.16, roa: 0.064, net_profit_margin: 0.08, asset_turnover: 0.8, financial_leverage: 2.5)
    expect(indicators.values.map(&:status)).to all(eq("available"))
    expect(indicators[:net_profit_margin].value * indicators[:asset_turnover].value * indicators[:financial_leverage].value)
      .to be_within(1e-12).of(indicators[:roe].value)
  end

  context "単体" do
    let(:consolidated) { false }
    it "親会社帰属利益ではなく当期純利益を使う" do
      expect(indicators[:roe].value).to eq 0.2
      expect(indicators[:roa].value).to eq 0.08
    end
  end

  it "売上高が欠けてもROE・ROA・レバレッジを表示できる" do
    items.delete("pl.revenue")
    expect(indicators[:roe].value).to eq 0.16
    expect(indicators[:roa].value).to eq 0.064
    expect(indicators[:financial_leverage].value).to eq 2.5
    expect(indicators.values_at(:net_profit_margin, :asset_turnover).map(&:status)).to eq %w[missing_data missing_data]
  end

  it "期首値がなければ期末値だけで代用しない（旧データも欠損として返す）" do
    items.delete("bs.assets_begin")
    items.delete("bs.equity_attributable_to_owners_begin")
    expect(indicators.values_at(:roe, :roa, :asset_turnover, :financial_leverage).map(&:status)).to all(eq("missing_data"))
    expect(indicators[:net_profit_margin].value).to eq 0.08
  end

  it "連結の親会社帰属利益がなくても全体利益にすり替えない" do
    items.delete("pl.profit_attributable_to_owners")
    expect(indicators.values_at(:roe, :roa, :net_profit_margin).map(&:status)).to all(eq("missing_data"))
    expect(indicators[:financial_leverage].value).to eq 2.5
  end

  [ 0, -10 ].each do |value|
    it "平均自己資本が#{value}ならROE・レバレッジは算出不可、ROAは残す" do
      items["bs.equity_attributable_to_owners_begin"] = value
      items["bs.equity_attributable_to_owners"] = value
      expect(indicators.values_at(:roe, :financial_leverage).map(&:status)).to all(eq("not_calculable"))
      expect(indicators[:roe].value).to be_nil
      expect(indicators[:roa].value).to eq 0.064
    end

    it "売上高が#{value}なら純利益率の分母として使えない" do
      items["pl.revenue"] = value
      expect(indicators[:net_profit_margin].status).to eq "not_calculable"
      expect(indicators[:roe].value).to eq 0.16
    end

    it "平均総資産が#{value}ならROA・回転率は算出不可" do
      items["bs.assets_begin"] = value
      items["bs.assets"] = value
      expect(indicators.values_at(:roa, :asset_turnover).map(&:status)).to all(eq("not_calculable"))
    end
  end

  [ 0, -80 ].each do |profit|
    it "利益#{profit}は欠損扱いせず符号を保つ" do
      items["pl.profit_attributable_to_owners"] = profit
      expect(indicators[:roe].value).to eq(profit / 500.0)
      expect(indicators[:roe].status).to eq "available"
    end
  end

  it "未対応形式などで全科目がなくても例外にならない" do
    items.clear
    expect(indicators.values.map(&:status)).to all(eq("missing_data"))
    expect(indicators.values.map(&:value)).to all(be_nil)
  end
end
