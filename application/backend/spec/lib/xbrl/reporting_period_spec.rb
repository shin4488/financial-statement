require "rails_helper"

RSpec.describe "XBRLの実日付による対象期間の照合" do
  def context(id, dates, entity: "E00001", scenario: "")
    period = dates.one? ? "<i:instant>#{dates.first}</i:instant>" :
      "<i:startDate>#{dates.first}</i:startDate><i:endDate>#{dates.last}</i:endDate>"
    <<~XML
      <i:context xmlns:i="http://www.xbrl.org/2003/instance" id="#{id}">
        <i:entity><i:identifier scheme="urn:test">#{entity}</i:identifier></i:entity>
        <i:period>#{period}</i:period>#{scenario}
      </i:context>
    XML
  end

  def load_document(contexts, facts)
    xml = synthetic_xbrl_xml(facts: facts)
      .sub("</xbrli:xbrl>", contexts.join + "</xbrli:xbrl>")
    Xbrl::Document.new(Nokogiri::XML(xml))
  end

  def bind_period(doc)
    doc.for_reporting_period(start_date: "2025-01-01", end_date: "2025-12-31")
  end

  let(:filing) { context("FilingDateInstant", [ "2026-09-07" ]) }

  it "日付に合う当期・期首を使い、元の検索結果は変えない" do
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ]),
      context("Prior2YearInstant", [ "2024-12-31" ]),
      context("Prior1YearDuration", [ "2025-01-01", "2025-12-31" ])
    ], {
      [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100,
      [ "jppfs_cor:Assets", "Prior2YearInstant" ] => 80,
      [ "jppfs_cor:NetSales", "Prior1YearDuration" ] => 20
    })
    period = bind_period(doc)
    expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 80
    expect(period.money("jppfs_cor:NetSales", "CurrentYearDuration")).to eq 20
    expect(doc.money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    expect(doc.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 100
  end

  it "期首欠損時に当期末を期首として使わず、期間開始日が異なる利益も使わない" do
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ]),
      context("Prior1YearDuration", [ "2025-07-01", "2025-12-31" ])
    ], {
      [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100,
      [ "jppfs_cor:ProfitLoss", "Prior1YearDuration" ] => 20
    })
    expect(bind_period(doc).money("jppfs_cor:Assets", "Prior1YearInstant")).to be_nil
    expect(bind_period(doc).money("jppfs_cor:ProfitLoss", "CurrentYearDuration")).to be_nil
  end

  it "同日付の候補が複数あれば一方を推測して使わない" do
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ]),
      context("Prior2YearInstant", [ "2025-12-31" ])
    ], { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
  end

  it "別企業と追加ディメンションの残高を合計残高に使わない" do
    segment = '<i:scenario><m:explicitMember xmlns:m="http://xbrl.org/2006/xbrldi" dimension="jppfs_cor:SomeAxis">jppfs_cor:SomeMember</m:explicitMember></i:scenario>'
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ], entity: "E99999"),
      context("Prior2YearInstant", [ "2025-12-31" ], scenario: segment)
    ], { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100,
         [ "jppfs_cor:Assets", "Prior2YearInstant" ] => 200 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
  end

  it "通常のCurrentYearコンテキストがある書類の検索は変更しない" do
    doc = load_document([ filing, context("CurrentYearInstant", [ "2025-12-31" ]) ],
                        { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
  end

  it "不正なDEI期間から別の年度を推測しない" do
    doc = load_document([ filing, context("Prior1YearInstant", [ "2025-12-31" ]) ], {})
    [ "", "2026-01-01" ].each do |start|
      period = doc.for_reporting_period(start_date: start, end_date: "2025-12-31")
      expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end
  end

  it "同じ日付の連結と単体を区別する" do
    member = '<i:scenario><m:explicitMember xmlns:m="http://xbrl.org/2006/xbrldi" dimension="jppfs_cor:ConsolidatedOrNonConsolidatedAxis">jppfs_cor:NonConsolidatedMember</m:explicitMember></i:scenario>'
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ]),
      context("Prior1YearInstant_NonConsolidatedMember", [ "2025-12-31" ], scenario: member)
    ], { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100,
         [ "jppfs_cor:Assets", "Prior1YearInstant_NonConsolidatedMember" ] => 60 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember")).to eq 60
  end

  it "同名でも企業拡張の軸・メンバーを標準の単体区分として使わない" do
    member = '<i:scenario><m:explicitMember xmlns:m="http://xbrl.org/2006/xbrldi" xmlns:ext="urn:extension" dimension="ext:ConsolidatedOrNonConsolidatedAxis">ext:NonConsolidatedMember</m:explicitMember></i:scenario>'
    doc = load_document([
      filing, context("Prior1YearInstant_NonConsolidatedMember", [ "2025-12-31" ], scenario: member)
    ], { [ "jppfs_cor:Assets", "Prior1YearInstant_NonConsolidatedMember" ] => 60 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember")).to be_nil
  end

  it "金額と同じ元コンテキストの開示精度を返す" do
    xml = synthetic_xbrl_xml(facts: { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 1_000_000 })
      .sub('contextRef="Prior1YearInstant"', 'contextRef="Prior1YearInstant" decimals="-6"')
      .sub("</xbrli:xbrl>", filing + context("Prior1YearInstant", [ "2025-12-31" ]) + "</xbrli:xbrl>")
    period = bind_period(Xbrl::Document.new(Nokogiri::XML(xml)))
    expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 1_000_000
    expect(period.rounding_error("jppfs_cor:Assets", "CurrentYearInstant")).to eq 1_000_000
  end
end
