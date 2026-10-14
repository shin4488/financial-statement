require "rails_helper"

RSpec.describe Charts::TwoSidedChart do
  let(:values) do
    { "bs.current_assets" => 400, "bs.non_current_assets" => 600, "bs.assets" => 1_000,
      "bs.liabilities" => 700, "bs.equity" => 300 }
  end

  # 金額の端数はどれも1（照合で許す差は、式に使った金額の数未満）
  def two_sided(values, debit_specs: [ [ "current", "流動資産", "bs.current_assets", "asset1" ],
                                      [ "fixed", "固定資産", "bs.non_current_assets", "asset2" ] ])
    items = FinancialStatements::Amounts.new
    values.each { |code, value| items.store(code, value, 1.to_d) }
    described_class.new(items, debit_specs: debit_specs, credit_specs: [ [ "liabilities", "負債", "bs.liabilities", "liability1" ] ],
                               equity: items["bs.equity"], equity_label: "純資産", base: items["bs.assets"],
                               unrenderable_note: "描けない")
  end

  it "借方と、負債・純資産の貸方の2本を描き、合計どうしが合えば照合の結果はnil" do
    result = two_sided(values)
    expect(result.chart.bars.map { |bar| [ bar.label, bar.segments.map(&:key) ] })
      .to eq [ [ "借方", %w[current fixed] ], [ "貸方", %w[liabilities equity] ] ]
    expect(result.mismatch).to be_nil
  end

  it "描いたグラフの資産合計が負債合計＋純資産合計と合わなければ、式に使った金額を返す" do
    result = two_sided(values.merge("bs.liabilities" => 710))
    expect(result.chart.renderable).to be true
    expect(result.mismatch).to eq("bs.current_assets" => 400, "bs.non_current_assets" => 600, "bs.assets" => 1_000,
                                  "bs.liabilities" => 710, "bs.equity" => 300)
  end

  it "描いた借方の合計が資産合計と合わなければ、式に使った金額を返す" do
    result = two_sided(values.merge("bs.assets" => 1_050))
    expect(result.chart.renderable).to be true
    expect(result.mismatch).to include("bs.current_assets" => 400, "bs.non_current_assets" => 600, "bs.assets" => 1_050)
  end

  it "差額で求めて金額で渡した借方の項目は、照合の金額に含めない" do
    result = two_sided(values.merge("bs.liabilities" => 710),
                       debit_specs: [ [ "current", "流動資産", "bs.current_assets", "asset1" ], [ "other", "その他資産", 600, "asset4" ] ])
    expect(result.mismatch).to eq("bs.current_assets" => 400, "bs.assets" => 1_000, "bs.liabilities" => 710, "bs.equity" => 300)
  end

  it "資産合計がなければ照合しない" do
    expect(two_sided(values.except("bs.assets").merge("bs.liabilities" => 710)).mismatch).to be_nil
  end

  it "貸借の差が1割を超えて描かないときは、合計どうしが合わなくても照合しない" do
    result = two_sided(values.merge("bs.liabilities" => 900))
    expect(result.chart).to have_attributes(renderable: false, note: "描けない", bars: [])
    expect(result.mismatch).to be_nil
  end
end
