require "rails_helper"

RSpec.describe Xbrl::CashFlowOpeningBalance do
  def money(value, decimals: "-3", unit: Xbrl::Fact::JPY)
    Xbrl::Fact.new(value: value.to_s, decimals: decimals, unit: unit)
  end

  def reconcile(opening: money(23_236_000), closing: money(36_621_000), change: money(13_385_000), adjustments: [])
    described_class.reconcile(opening: opening, closing: closing, change: change, adjustments: adjustments)
  end

  it "同じCFの増減と整合する開示期首額を返す" do
    expect(reconcile.money).to eq 23_236_000
  end

  it "丸め差のある場合も計算で作った金額でなく開示額を保持する" do
    expect(reconcile(opening: money(1_546_456_000), closing: money(1_530_664_000), change: money(-15_791_000)).money)
      .to eq 1_546_456_000
  end

  it "連結範囲変更の増減を加えて照合する" do
    expect(reconcile(closing: money(37_621_000), adjustments: [ money(1_000_000) ]).money).to eq 23_236_000
    expect(reconcile(closing: money(37_621_000))).to be_nil
  end

  it "開示精度の上限に達する差や、精度不明を許容しない" do
    expect(reconcile(closing: money(36_624_000))).to be_nil
    expect(reconcile(opening: money(23_236_000, decimals: nil))).to be_nil
  end

  it "不足・不正な数値や通貨の混在から補完しない" do
    expect(reconcile(change: nil)).to be_nil
    expect(reconcile(opening: money("invalid"))).to be_nil
    expect(reconcile(change: money(13_385_000, unit: "USD"))).to be_nil
    expect(reconcile(opening: money(-1))).to be_nil
  end

  it "厳密な0も開示値として扱う" do
    expect(reconcile(opening: money(0, decimals: "INF"), closing: money(10, decimals: "INF"), change: money(10, decimals: "INF")).money).to eq 0
  end
end
