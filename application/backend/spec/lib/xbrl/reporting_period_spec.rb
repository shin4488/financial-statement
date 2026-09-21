require "rails_helper"

RSpec.describe "XBRLの実日付による対象期間の照合" do
  def context(id, dates, entity: "E00001", scheme: "urn:test", scenario: "")
    period = dates.one? ? "<i:instant>#{dates.first}</i:instant>" :
      "<i:startDate>#{dates.first}</i:startDate><i:endDate>#{dates.last}</i:endDate>"
    <<~XML
      <i:context xmlns:i="http://www.xbrl.org/2003/instance" id="#{id}">
        <i:entity><i:identifier scheme="#{scheme}">#{entity}</i:identifier></i:entity>
        <i:period>#{period}</i:period>#{scenario}
      </i:context>
    XML
  end

  def load_document(contexts, facts)
    xml = synthetic_xbrl_xml(facts: facts, contexts: [])
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

  it "同日付の候補の値が食い違えば一方を推測して使わない" do
    doc = load_document([
      filing, context("Prior1YearInstant", [ "2025-12-31" ]),
      context("Prior2YearInstant", [ "2025-12-31" ])
    ], { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 100,
         [ "jppfs_cor:Assets", "Prior2YearInstant" ] => 200 })
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
    xml = synthetic_xbrl_xml(facts: { [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 1_000_000 }, contexts: [])
      .sub('contextRef="Prior1YearInstant"', 'contextRef="Prior1YearInstant" decimals="-6"')
      .sub("</xbrli:xbrl>", filing + context("Prior1YearInstant", [ "2025-12-31" ]) + "</xbrli:xbrl>")
    period = bind_period(Xbrl::Document.new(Nokogiri::XML(xml)))
    expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 1_000_000
    expect(period.rounding_error("jppfs_cor:Assets", "CurrentYearInstant")).to eq 1_000_000
  end

  it "標準名と任意のIDが混在していても、期首・期末・期間をそれぞれ照合する" do
    doc = load_document([
      filing, context("CurrentYearInstant", [ "2025-12-31" ]),
      context("opening_balance", [ "2024-12-31" ]),
      context("annual_result", [ "2025-01-01", "2025-12-31" ])
    ], { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100,
         [ "jppfs_cor:Assets", "opening_balance" ] => 80,
         [ "jppfs_cor:NetSales", "annual_result" ] => 20 })
    period = bind_period(doc)
    expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 80
    expect(period.money("jppfs_cor:NetSales", "CurrentYearDuration")).to eq 20
  end

  it "CurrentYearという名前でも期末が異なる年度を採用しない" do
    doc = load_document([
      filing, context("CurrentYearInstant", [ "2026-12-31" ]),
      context("CurrentYearDuration", [ "2026-01-01", "2026-12-31" ]),
      context("closing", [ "2025-12-31" ]),
      context("annual", [ "2025-01-01", "2025-12-31" ])
    ], { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 999,
         [ "jppfs_cor:Assets", "closing" ] => 100,
         [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 999,
         [ "jppfs_cor:NetSales", "annual" ] => 20 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    expect(bind_period(doc).money("jppfs_cor:NetSales", "CurrentYearDuration")).to eq 20
  end

  it "同じ意味のcontextに分散した科目・同一値の重複を読み取る" do
    doc = load_document([ filing, context("a", [ "2025-12-31" ]), context("b", [ "2025-12-31" ]) ], {
      [ "jppfs_cor:Assets", "a" ] => 100, [ "jppfs_cor:Assets", "b" ] => 100,
      [ "jppfs_cor:NetAssets", "b" ] => 60
    })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
    expect(bind_period(doc).money("jppfs_cor:NetAssets", "CurrentYearInstant")).to eq 60
  end

  it "重複候補の精度・単位が異なれば値と精度を推測しない" do
    [ 'decimals="-3"', 'unitRef="USD"' ].each do |attribute|
      xml = synthetic_xbrl_xml(contexts: [ filing, context("a", [ "2025-12-31" ]), context("b", [ "2025-12-31" ]) ],
                               facts: { [ "jppfs_cor:Assets", "a" ] => 1000, [ "jppfs_cor:Assets", "b" ] => 1000 })
        .sub('contextRef="b"', "contextRef=\"b\" #{attribute}")
      period = bind_period(Xbrl::Document.new(Nokogiri::XML(xml)))
      expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
      expect(period.rounding_error("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end
  end

  it "IDの単体サフィックスではなく実際のディメンションを使う" do
    member = '<i:scenario><d:explicitMember xmlns:d="http://xbrl.org/2006/xbrldi" xmlns:alt="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor" dimension="alt:ConsolidatedOrNonConsolidatedAxis">alt:NonConsolidatedMember</d:explicitMember></i:scenario>'
    doc = load_document([ filing, context("CurrentYearInstant", [ "2025-12-31" ], scenario: member) ],
                        { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 60 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember")).to eq 60
  end

  it "context定義・提出者の企業識別子・有効な期間がなければIDだけで取得しない" do
    [ [], [ filing ], [ context("CurrentYearInstant", [ "2025-12-31" ]) ],
      [ filing, context("CurrentYearInstant", [ "2025-02-30" ]) ],
      [ filing, context("CurrentYearInstant", [ "2025-12-31T00:00:00" ]) ] ].each do |contexts|
      doc = load_document(contexts, { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 })
      expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end
  end

  it "不正なDEI期間でも標準名のfactをそのまま返さない" do
    doc = load_document([ filing, context("CurrentYearInstant", [ "2025-12-31" ]) ],
                        { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 })
    expect(doc.for_reporting_period(start_date: "", end_date: "2025-12-31")
              .money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
  end

  it "連結と単体の年度開始日が異なるとき、それぞれの損益期間と期首を使う" do
    member = '<i:scenario><m:explicitMember xmlns:m="http://xbrl.org/2006/xbrldi" dimension="jppfs_cor:ConsolidatedOrNonConsolidatedAxis">jppfs_cor:NonConsolidatedMember</m:explicitMember></i:scenario>'
    doc = load_document([
      filing, context("CurrentYearDuration", [ "2024-07-01", "2025-12-31" ]),
      context("CurrentYearDuration_NonConsolidatedMember", [ "2025-01-01", "2025-12-31" ], scenario: member),
      context("group_opening", [ "2024-06-30" ]),
      context("parent_opening", [ "2024-12-31" ], scenario: member),
      context("other_date", [ "2024-12-31" ])
    ], { [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 300,
         [ "jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember" ] => 60,
         [ "jppfs_cor:Assets", "group_opening" ] => 200,
         [ "jppfs_cor:Assets", "parent_opening" ] => 80,
         [ "jppfs_cor:Assets", "other_date" ] => 999 })
    period = bind_period(doc)
    expect(period.money("jppfs_cor:NetSales", "CurrentYearDuration")).to eq 300
    expect(period.money("jppfs_cor:NetSales", "CurrentYearDuration_NonConsolidatedMember")).to eq 60
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 200
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant_NonConsolidatedMember")).to eq 80
  end

  it "企業識別子が同じでもschemeが異なれば別企業として除外する" do
    doc = load_document([ filing, context("CurrentYearInstant", [ "2025-12-31" ], scheme: "urn:another") ],
                        { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
  end

  it "連結区分をsegmentで明示しているcontextも意味で照合する" do
    explicit = '<i:segment><d:explicitMember xmlns:d="http://xbrl.org/2006/xbrldi" dimension="jppfs_cor:ConsolidatedOrNonConsolidatedAxis">jppfs_cor:ConsolidatedMember</d:explicitMember></i:segment>'
    closing = context("closing", [ "2025-12-31" ]).sub("</i:entity>", explicit + "</i:entity>")
    doc = load_document([ filing, closing ], { [ "jppfs_cor:Assets", "closing" ] => 100 })
    expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
  end

  it "typedMember・予測の区分・追加の内容があるcontextを全社実績に使わない" do
    [ '<d:typedMember dimension="jppfs_cor:SomeAxis"><value>A</value></d:typedMember>',
      '<d:explicitMember dimension="jppfs_cor:ForecastAndResultAxis">jppfs_cor:ForecastMember</d:explicitMember>',
      'forecast' ].each do |content|
      scenario = %(<i:scenario xmlns:d="http://xbrl.org/2006/xbrldi">#{content}</i:scenario>)
      doc = load_document([ filing, context("CurrentYearInstant", [ "2025-12-31" ], scenario: scenario) ],
                          { [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 100 })
      expect(bind_period(doc).money("jppfs_cor:Assets", "CurrentYearInstant")).to be_nil
    end
  end

  it "短期決算でも開始日の前日を期首とし、閏日を正しく扱う" do
    doc = load_document([ filing, context("opening", [ "2024-02-29" ]), context("closing", [ "2024-06-30" ]) ],
                        { [ "jppfs_cor:Assets", "opening" ] => 80, [ "jppfs_cor:Assets", "closing" ] => 100 })
    period = doc.for_reporting_period(start_date: "2024-03-01", end_date: "2024-06-30")
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 80
    expect(period.money("jppfs_cor:Assets", "CurrentYearInstant")).to eq 100
  end
end

RSpec.describe "CFの期首額の照合はBSの期首検索を緩めない" do
  def extraction(opening_date: "2023-12-31", opening_cash: 100, entity: "E00001", alias_ids: false, competing: false)
    xml = <<~XML
      <i:xbrl xmlns:i="http://www.xbrl.org/2003/instance" xmlns:c="http://www.xbrl.org/2003/iso4217"
       xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor">
      <i:unit id="yen"><i:measure>c:JPY</i:measure></i:unit>
    XML
    { "FilingDateInstant" => [ "2026-03-01" ], "CurrentYearInstant" => [ "2025-12-31" ],
      "CurrentYearDuration" => [ "2025-01-01", "2025-12-31" ], "Prior1YearInstant" => [ opening_date ] }.each do |id, dates|
      period = dates.one? ? "<i:instant>#{dates.first}</i:instant>" :
        "<i:startDate>#{dates.first}</i:startDate><i:endDate>#{dates.last}</i:endDate>"
      owner = id == "Prior1YearInstant" ? entity : "E00001"
      xml += "<i:context id='#{id}'><i:entity><i:identifier scheme='urn:test'>#{owner}</i:identifier></i:entity><i:period>#{period}</i:period></i:context>"
    end
    { [ "CashAndCashEquivalents", "Prior1YearInstant" ] => opening_cash,
      [ "CashAndCashEquivalents", "CurrentYearInstant" ] => 120,
      [ "NetIncreaseDecreaseInCashAndCashEquivalents", "CurrentYearDuration" ] => 20,
      [ "Assets", "Prior1YearInstant" ] => 500,
      [ "Assets", "CurrentYearInstant" ] => 600 }.each do |(tag, ctx), amount|
      xml += "<jppfs_cor:#{tag} contextRef='#{ctx}' unitRef='yen' decimals='INF'>#{amount}</jppfs_cor:#{tag}>"
    end
    if competing
      xml += <<~XML
        <i:context id="AnotherOpening"><i:entity><i:identifier scheme="urn:test">E00001</i:identifier></i:entity><i:period><i:instant>2022-12-31</i:instant></i:period></i:context>
        <jppfs_cor:CashAndCashEquivalents contextRef="AnotherOpening" unitRef="yen" decimals="-1">101</jppfs_cor:CashAndCashEquivalents>
      XML
    end
    xml = xml.gsub("Prior1YearInstant", "OpeningCash").gsub("CurrentYearDuration", "CurrentPeriod") if alias_ids
    period = Xbrl::Document.new(Nokogiri::XML(xml + "</i:xbrl>"))
      .for_reporting_period(start_date: "2025-01-01", end_date: "2025-12-31")
    Ingestion::Extractors::JgaapGeneral.new(period, "").extract
  end

  it "期首日付が誤っていても現金の増減が一致すればCFだけ補完する" do
    result = extraction
    expect(result).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
    expect(result).not_to have_key("bs.assets_begin")
    expect(result).not_to have_key("bs.equity_attributable_to_owners_begin")
  end

  it "一致しない金額・別企業・当期末以降の値は使わない" do
    expect(extraction(opening_cash: 90)).not_to have_key("cf.cash_begin")
    expect(extraction(entity: "E99999")).not_to have_key("cf.cash_begin")
    expect(extraction(opening_date: "2025-12-31")).not_to have_key("cf.cash_begin")
  end

  it "当期・期首のcontextが任意のIDでも同じ結果を返す" do
    expect(extraction(alias_ids: true)).to include("cf.cash_begin" => 100)
  end

  it "開示精度の範囲で複数候補が成立するときは推測で選ばない" do
    expect(extraction(competing: true)).not_to have_key("cf.cash_begin")
  end
end
