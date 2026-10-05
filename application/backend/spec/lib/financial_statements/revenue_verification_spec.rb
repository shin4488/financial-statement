require "rails_helper"

RSpec.describe FinancialStatements::RevenueVerification do
  # values: { 科目コード => [金額, 端数の上限] }
  def status(values)
    amounts = FinancialStatements::Amounts.new
    values.each do |code, (amount, error)|
      amounts[code] = amount
      amounts.rounding_errors[code] = error&.to_d
    end
    described_class.status(amounts)
  end

  it "売上が要約の売上と端数の範囲で一致すれば、確かめられたとする" do
    # ミニストップ単体: 売上高43,082＋営業収入27,542百万円と、要約の営業総収入70,625百万円
    expect(status("pl.revenue" => [ 70_624_000_000, 2_000_000 ], "pl.summary_revenue" => [ 70_625_000_000, 1_000_000 ]))
      .to eq :matched
  end

  it "売上が内訳だけで要約の売上と合わなければ、一致しないとする" do
    # スリー・ディー・マトリックス 2017年4月期: 製品売上高107,127千円と、要約の事業収益615,852千円
    expect(status("pl.revenue" => [ 107_127_000, 1_000 ], "pl.summary_revenue" => [ 615_852_000, 1_000 ]))
      .to eq :mismatched
  end

  describe "売上を営業収益（売上高＋営業収入）とし、要約には売上高だけを載せる会社" do
    # ベルク: 売上高297,019＋営業収入3,248百万円
    let(:values) do
      { "pl.revenue" => [ 300_267_000_000, 2_000_000 ], "pl.summary_revenue" => [ 297_019_000_000, 1_000_000 ] }
    end

    it "売上から本表の営業収入を除いた額が要約の売上高と合えば、確かめられたとする" do
      expect(status(values.merge("pl.non_sales_operating_revenue" => [ 3_248_000_000, 1_000_000 ]))).to eq :matched
    end

    it "営業収入を除いても合わなければ、一致しないとする" do
      expect(status(values.merge("pl.non_sales_operating_revenue" => [ 1_000_000_000, 1_000_000 ]))).to eq :mismatched
    end
  end

  it "要約に売上があるのに売上が取れなければ、そのことを返す" do
    expect(status("pl.summary_revenue" => [ 110_441_000_000, 1_000_000 ])).to eq :revenue_missing
  end

  it "要約に売上がなければ照合できない" do
    expect(status("pl.revenue" => [ 276_862_000_000, 1_000_000 ])).to eq :unverifiable
  end
end
