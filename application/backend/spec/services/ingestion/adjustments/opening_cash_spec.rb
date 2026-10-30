require "rails_helper"

RSpec.describe Ingestion::Adjustments::OpeningCash do
  # 開示した金額。decimals は開示の精度（-3なら千円単位。nilなら精度不明）、unit は通貨
  def money(value, decimals: "-3", unit: "JPY") = { value: value, decimals: decimals, unit: unit }

  # 当期（2025年）の現金及び現金同等物の期末残・当期増減・新規連結による増加（adjustments）と、当期の期首より前の時点（2023年末）の
  # 残高（opening）を開示したXBRLから、期末残だけを抽出した金額の表に補正ルールを適用し、補った期首残を返す（補わなければ nil）。
  # 期首（2024年末）の残高は開示していないため、期首残は取得式では取れない
  def supplemented_opening(opening: money(23_236_000), closing: money(36_621_000), change: money(13_385_000), adjustments: [])
    facts = { [ "jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant" ] => closing,
              [ "jppfs_cor:NetIncreaseDecreaseInCashAndCashEquivalents", "CurrentYearDuration" ] => change,
              [ "jppfs_cor:IncreaseInCashAndCashEquivalentsFromNewlyConsolidatedSubsidiaryCCE", "CurrentYearDuration" ] => adjustments.first,
              [ "jppfs_cor:CashAndCashEquivalents", "OpeningCash" ] => opening }
    period = reporting_period(facts.compact)
    amounts = FinancialStatements::Amounts.new
    amounts.store("cf.cash_end", period.money("jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant"),
                  period.rounding_error("jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant"))
    described_class.apply(amounts, mapping: nil, source: period, consolidation: :consolidated)
    amounts["cf.cash_begin"] if amounts.key?("cf.cash_begin")
  end

  def reporting_period(facts)
    contexts = { "FilingDateInstant" => "<i:instant>2026-03-01</i:instant>", "CurrentYearInstant" => "<i:instant>2025-12-31</i:instant>",
                 "CurrentYearDuration" => "<i:startDate>2025-01-01</i:startDate><i:endDate>2025-12-31</i:endDate>",
                 "OpeningCash" => "<i:instant>2023-12-31</i:instant>" }
    xml = +<<~XML
      <i:xbrl xmlns:i="http://www.xbrl.org/2003/instance" xmlns:c="http://www.xbrl.org/2003/iso4217"
       xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor">
      <i:unit id="JPY"><i:measure>c:JPY</i:measure></i:unit><i:unit id="USD"><i:measure>c:USD</i:measure></i:unit>
    XML
    contexts.each do |id, period|
      xml << "<i:context id='#{id}'><i:entity><i:identifier scheme='urn:test'>E00001</i:identifier></i:entity><i:period>#{period}</i:period></i:context>"
    end
    facts.each do |(qname, context), fact|
      decimals = " decimals='#{fact[:decimals]}'" if fact[:decimals]
      xml << "<#{qname} contextRef='#{context}' unitRef='#{fact[:unit]}'#{decimals}>#{fact[:value]}</#{qname}>"
    end
    Xbrl::Document.new(Nokogiri::XML(xml + "</i:xbrl>")).for_reporting_period(start_date: "2025-01-01", end_date: "2025-12-31")
  end

  it "同じCFの増減と整合する開示期首額で補う" do
    expect(supplemented_opening).to eq 23_236_000
  end

  it "丸め差のある場合も計算で作った金額でなく開示額で補う" do
    expect(supplemented_opening(opening: money(1_546_456_000), closing: money(1_530_664_000), change: money(-15_791_000)))
      .to eq 1_546_456_000
  end

  it "連結範囲変更の増減を加えて照合する" do
    expect(supplemented_opening(closing: money(37_621_000), adjustments: [ money(1_000_000) ])).to eq 23_236_000
    expect(supplemented_opening(closing: money(37_621_000))).to be_nil
  end

  it "連結範囲変更の増減が外貨・不正な数値のときや、精度不明で差があるときは補完しない" do
    # 連結範囲変更等を式から除いて照合しても、式が合う入力にする
    expect(supplemented_opening(adjustments: [ money(0, unit: "USD") ])).to be_nil
    expect(supplemented_opening(adjustments: [ money("invalid") ])).to be_nil
    # 差が0なら精度によらず一致とするため、期末残を1,000ずらし、ほかの金額の端数の範囲内の差を作る
    expect(supplemented_opening(closing: money(36_622_000), adjustments: [ money(0, decimals: nil) ])).to be_nil
  end

  it "開示精度の上限に達する差や、精度不明の金額を含む差を許容しない" do
    expect(supplemented_opening(closing: money(36_624_000))).to be_nil
    expect(supplemented_opening(opening: money(23_236_000, decimals: nil), closing: money(36_622_000))).to be_nil
  end

  it "不足・不正な数値や通貨の混在から補完しない" do
    expect(supplemented_opening(change: nil)).to be_nil
    expect(supplemented_opening(opening: money("invalid"))).to be_nil
    expect(supplemented_opening(change: money(13_385_000, unit: "USD"))).to be_nil
    # 単位の定義がなく、円か分からない金額
    expect(supplemented_opening(change: money(13_385_000, unit: "Undeclared"))).to be_nil
    expect(supplemented_opening(opening: money(-1))).to be_nil
  end

  it "式が合っても、期首残や期末残がマイナスなら補完しない" do
    expect(supplemented_opening(opening: money(-1_000_000), change: money(37_621_000))).to be_nil
    expect(supplemented_opening(closing: money(-1_000_000), change: money(-24_236_000))).to be_nil
  end

  it "厳密な0も開示値として扱う" do
    expect(supplemented_opening(opening: money(0, decimals: "INF"), closing: money(10, decimals: "INF"), change: money(10, decimals: "INF")))
      .to eq 0
  end
end
