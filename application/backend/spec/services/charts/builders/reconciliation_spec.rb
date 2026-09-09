require "rails_helper"

RSpec.describe "開示精度による財務検算" do
  let(:values) { { "bs.assets" => 1_000_000, "bs.liabilities" => 600_000, "bs.equity" => 399_999 } }

  it "同じ1円差でも精度不明なら許容せず、明示された表示単位内なら許容する" do
    expect(Charts::Builders::BsJgaapBank.new(values).build.renderable).to be false
    expect(Charts::Builders::BsJgaapBank.new(rounded_amounts(values)).build.renderable).to be true
  end

  it "許容差は比較対象の科目だけで決まり、無関係な科目の粗い精度で広がらない" do
    amounts = rounded_amounts(values.merge("bs.equity" => 390_000))
    amounts["pl.revenue"] = 10_000_000
    amounts.rounding_errors["pl.revenue"] = 1_000_000.to_d
    expect(Charts::Builders::BsJgaapBank.new(amounts).build.renderable).to be false
  end

  it "銀行PLも経常収益・費用・利益の不整合を拒否する" do
    amounts = { "pl.ordinary_revenue" => 1_000, "pl.ordinary_expenses" => 800, "pl.ordinary_profit" => 190 }
    expect(Charts::Builders::PlJgaapFinancialInstitution.new(amounts).build.renderable).to be false
  end

  it "CFの説明されない差額は埋めずに表示を止める" do
    amounts = { "cf.cash_begin" => 100, "cf.operating" => 20, "cf.investing" => -10,
               "cf.financing" => -5, "cf.cash_end" => 110 }
    expect(Charts::Builders::CashFlow.new(amounts).build.renderable).to be false
    chart = Charts::Builders::CashFlow.new(amounts.merge("cf.exchange_effect" => 5)).build
    expect(chart.renderable).to be true
    expect(chart.steps.map(&:amount)).to eq [ 100, 20, -10, -5, 5, 110 ]
  end

  it "連結範囲の純増減と新規連結増加額を二重に加算しない" do
    amounts = { "cf.cash_begin" => 100, "cf.operating" => 20, "cf.investing" => -10,
               "cf.financing" => -5, "cf.cash_end" => 110,
               "cf.consolidation_change" => 5, "cf.new_consolidation" => 8 }
    chart = Charts::Builders::CashFlow.new(amounts).build
    expect(chart.renderable).to be true
    expect(chart.steps.select { |s| s.key == "consolidationChange" }.map(&:amount)).to eq [ 5 ]
  end
end
