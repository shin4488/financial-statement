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

  it "当期の期間の宣言（CurrentYearDuration）の期間を読めなければ、宣言を使わずDEIの期首で当期・期首を引く" do
    doc = load_document([
      filing, context("CurrentYearDuration", [ "2024-07-01", "2025-02-30" ]),
      context("annual", [ "2025-01-01", "2025-12-31" ]), context("opening", [ "2024-12-31" ])
    ], { [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 999,
         [ "jppfs_cor:NetSales", "annual" ] => 20,
         [ "jppfs_cor:Assets", "opening" ] => 80 })
    period = bind_period(doc)
    expect(period.money("jppfs_cor:NetSales", "CurrentYearDuration")).to eq 20
    expect(period.money("jppfs_cor:Assets", "Prior1YearInstant")).to eq 80
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
    Ingestion::StatementExtractor.amounts(Ingestion::Mappings::JgaapGeneral, source: period, consolidation: :consolidated)
  end

  it "期首日付が誤っていても現金の増減が一致すればCFだけ補完する" do
    result = extraction
    expect(result.to_h).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
    expect(result.to_h).not_to have_key("bs.assets_begin")
    expect(result.to_h).not_to have_key("bs.equity_attributable_to_owners_begin")
  end

  it "一致しない金額・別企業・当期末以降の値は使わない" do
    expect(extraction(opening_cash: 90).to_h).not_to have_key("cf.cash_begin")
    expect(extraction(entity: "E99999").to_h).not_to have_key("cf.cash_begin")
    expect(extraction(opening_date: "2025-12-31").to_h).not_to have_key("cf.cash_begin")
  end

  it "当期・期首のcontextが任意のIDでも同じ結果を返す" do
    expect(extraction(alias_ids: true).to_h).to include("cf.cash_begin" => 100)
  end

  it "開示精度の範囲で複数候補が成立するときは推測で選ばない" do
    expect(extraction(competing: true).to_h).not_to have_key("cf.cash_begin")
  end
end

RSpec.describe "CFの期首額を補完する条件" do
  let(:contexts) do
    { "FilingDateInstant" => "<i:instant>2026-03-01</i:instant>", "CurrentYearInstant" => "<i:instant>2025-12-31</i:instant>",
      "CurrentYearDuration" => "<i:startDate>2025-01-01</i:startDate><i:endDate>2025-12-31</i:endDate>",
      "OpeningCash" => "<i:instant>2023-12-31</i:instant>" }
  end

  # facts: { [タグ, contextのID] => 金額 }。円単位で、開示精度は decimals で指定したもの以外はINF
  def extract(mapping, facts, extra_contexts: {}, decimals: {})
    xml = +<<~XML
      <i:xbrl xmlns:i="http://www.xbrl.org/2003/instance" xmlns:c="http://www.xbrl.org/2003/iso4217"
       xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor"
       xmlns:jpigp_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jpigp/2025-11-01/jpigp_cor"
       xmlns:jpcrp_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jpcrp/2025-11-01/jpcrp_cor">
      <i:unit id="yen"><i:measure>c:JPY</i:measure></i:unit>
    XML
    contexts.merge(extra_contexts).each do |id, period|
      xml << "<i:context id='#{id}'><i:entity><i:identifier scheme='urn:test'>E00001</i:identifier></i:entity><i:period>#{period}</i:period></i:context>"
    end
    facts.each do |(qname, context), amount|
      xml << "<#{qname} contextRef='#{context}' unitRef='yen' decimals='#{decimals.fetch([ qname, context ], 'INF')}'>#{amount}</#{qname}>"
    end
    period = Xbrl::Document.new(Nokogiri::XML(xml + "</i:xbrl>")).for_reporting_period(start_date: "2025-01-01", end_date: "2025-12-31")
    Ingestion::StatementExtractor.amounts(mapping, source: period, consolidation: :consolidated)
  end

  let(:opening_and_change) do
    { [ "jppfs_cor:CashAndCashEquivalents", "OpeningCash" ] => 100,
      [ "jppfs_cor:NetIncreaseDecreaseInCashAndCashEquivalents", "CurrentYearDuration" ] => 20 }
  end

  it "期末残を経営指標の要約のタグで取り、原本の期末残（日本基準のタグ）がなければ補完しない" do
    result = extract(Ingestion::Mappings::JgaapGeneral, opening_and_change.merge(
      [ "jpcrp_cor:CashAndCashEquivalentsSummaryOfBusinessResults", "CurrentYearInstant" ] => 120))
    expect(result.to_h).to include("cf.cash_end" => 120)
    expect(result.to_h).not_to have_key("cf.cash_begin")
  end

  it "原本の期末残（日本基準のタグ）が、別のタグで取った期末残と違えば補完しない（同じなら補完する）" do
    # 期末残の最初の候補が日本基準のタグでない形式（IFRSなど）でだけ、2つの期末残が食い違い得る
    ifrs_closing = { [ "jpigp_cor:CashAndCashEquivalentsIFRS", "CurrentYearInstant" ] => 120 }
    differing = extract(Ingestion::Mappings::IfrsClassified, opening_and_change.merge(ifrs_closing).merge(
      [ "jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant" ] => 140,
      [ "jppfs_cor:CashAndCashEquivalents", "OpeningCash" ] => 120))
    expect(differing.to_h).to include("cf.cash_end" => 120)
    expect(differing.to_h).not_to have_key("cf.cash_begin")

    same = extract(Ingestion::Mappings::IfrsClassified, opening_and_change.merge(ifrs_closing).merge(
      [ "jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant" ] => 120))
    expect(same.to_h).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
  end

  it "期間を読めないcontextは候補にせず、ほかのcontextの期首残で補完する" do
    # 期間を読めるなら、開示精度の範囲でCFの式を満たす2つ目の候補になり、補完しなくなる値
    result = extract(Ingestion::Mappings::JgaapGeneral, opening_and_change.merge(
      [ "jppfs_cor:CashAndCashEquivalents", "CurrentYearInstant" ] => 120,
      [ "jppfs_cor:CashAndCashEquivalents", "UnreadablePeriod" ] => 101),
      extra_contexts: { "UnreadablePeriod" => "<i:instant>2023-02-30</i:instant>" },
      decimals: { [ "jppfs_cor:CashAndCashEquivalents", "UnreadablePeriod" ] => "-1" })
    expect(result.to_h).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
  end
end

RSpec.describe "期間と連結区分のシンボルによる検索と、CFの期首額の補完" do
  let(:filing) { context_xml("FilingDateInstant", [ "2026-03-01" ]) }
  let(:non_consolidated) do
    '<i:scenario><m:explicitMember dimension="jppfs_cor:ConsolidatedOrNonConsolidatedAxis">jppfs_cor:NonConsolidatedMember</m:explicitMember></i:scenario>'
  end

  def context_xml(id, dates, entity: "E00001", scenario: "")
    period = dates.one? ? "<i:instant>#{dates.first}</i:instant>" :
      "<i:startDate>#{dates.first}</i:startDate><i:endDate>#{dates.last}</i:endDate>"
    "<i:context id='#{id}'><i:entity><i:identifier scheme='urn:test'>#{entity}</i:identifier></i:entity><i:period>#{period}</i:period>#{scenario}</i:context>"
  end

  # facts: { [jppfs_corの要素名, contextのID] => 金額 }。単位は円で、開示精度は decimals で指定したもの以外はINF
  def load_document(contexts, facts, decimals: {})
    xml = +<<~XML
      <i:xbrl xmlns:i="http://www.xbrl.org/2003/instance" xmlns:c="http://www.xbrl.org/2003/iso4217" xmlns:m="http://xbrl.org/2006/xbrldi"
       xmlns:jppfs_cor="http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor">
      <i:unit id="yen"><i:measure>c:JPY</i:measure></i:unit>
    XML
    xml << contexts.join
    facts.each do |(name, id), amount|
      xml << "<jppfs_cor:#{name} contextRef='#{id}' unitRef='yen' decimals='#{decimals.fetch([ name, id ], 'INF')}'>#{amount}</jppfs_cor:#{name}>"
    end
    Xbrl::Document.new(Nokogiri::XML(xml + "</i:xbrl>"))
  end

  def bind_period(doc) = doc.for_reporting_period(start_date: "2025-01-01", end_date: "2025-12-31")

  describe "期間と連結区分による検索" do
    it "期間と連結区分をシンボルで指定し、値・開示精度・単位を組で返す" do
      doc = load_document([
        filing, context_xml("closing", [ "2025-12-31" ]), context_xml("year", [ "2025-01-01", "2025-12-31" ]),
        context_xml("opening", [ "2024-12-31" ]), context_xml("parent_closing", [ "2025-12-31" ], scenario: non_consolidated)
      ], { [ "Assets", "closing" ] => 300, [ "NetSales", "year" ] => 50, [ "Assets", "opening" ] => 200,
           [ "Assets", "parent_closing" ] => 60 },
         decimals: { [ "Assets", "parent_closing" ] => "-3" })
      period = bind_period(doc)
      expect(period.fact("jppfs_cor:Assets", period: :instant, consolidation: :consolidated))
        .to eq Xbrl::Fact.new(value: "300", decimals: "INF", unit: Xbrl::Fact::JPY)
      expect(period.fact("jppfs_cor:NetSales", period: :duration, consolidation: :consolidated).money).to eq 50
      expect(period.fact("jppfs_cor:Assets", period: :prior_instant, consolidation: :consolidated).money).to eq 200
      expect(period.fact("jppfs_cor:Assets", period: :instant, consolidation: :non_consolidated))
        .to eq Xbrl::Fact.new(value: "60", decimals: "-3", unit: Xbrl::Fact::JPY)
      expect(period.fact("jppfs_cor:Assets", period: :prior_instant, consolidation: :non_consolidated)).to be_nil
    end

    it "区分ごとの当期の開始日より前の時点の値を、企業と連結区分が一致するcontextに限ってすべて返す" do
      other_axis = '<i:scenario><m:explicitMember dimension="jppfs_cor:SomeAxis">jppfs_cor:SomeMember</m:explicitMember></i:scenario>'
      # 連結の当期は2024-07-01から、単体の当期は2025-01-01から
      doc = load_document([
        filing, context_xml("CurrentYearDuration", [ "2024-07-01", "2025-12-31" ]),
        context_xml("CurrentYearDuration_NonConsolidatedMember", [ "2025-01-01", "2025-12-31" ], scenario: non_consolidated),
        context_xml("group_opening", [ "2024-06-30" ]), context_xml("group_older", [ "2022-03-31" ]),
        context_xml("group_in_period", [ "2024-12-31" ]),
        context_xml("parent_opening", [ "2024-12-31" ], scenario: non_consolidated),
        context_xml("other_entity", [ "2023-12-31" ], entity: "E99999"),
        context_xml("other_axis", [ "2023-12-31" ], scenario: other_axis),
        context_xml("prior_year", [ "2023-07-01", "2024-06-30" ])
      ], { "group_opening" => 200, "group_older" => 150, "group_in_period" => 999, "parent_opening" => 80,
           "other_entity" => 1, "other_axis" => 2, "prior_year" => 3 }.transform_keys { |id| [ "CashAndCashEquivalents", id ] })
      period = bind_period(doc)
      expect(period.facts_before_period("jppfs_cor:CashAndCashEquivalents", consolidation: :consolidated).map(&:money))
        .to contain_exactly(200, 150)
      expect(period.facts_before_period("jppfs_cor:CashAndCashEquivalents", consolidation: :non_consolidated).map(&:money))
        .to contain_exactly(80)
    end

    it "当期を決められない書類では、過去の時点の値も返さない" do
      doc = load_document([ filing, context_xml("opening", [ "2023-12-31" ]) ], { [ "CashAndCashEquivalents", "opening" ] => 100 })
      expect(bind_period(doc).facts_before_period("jppfs_cor:CashAndCashEquivalents", consolidation: :consolidated).map(&:money))
        .to eq [ 100 ]
      period = doc.for_reporting_period(start_date: "", end_date: "2025-12-31")
      expect(period.facts_before_period("jppfs_cor:CashAndCashEquivalents", consolidation: :consolidated)).to eq []
    end
  end

  describe "CFの期首額を補完する入口と区分" do
    let(:current) do
      [ filing, context_xml("CurrentYearInstant", [ "2025-12-31" ]), context_xml("CurrentYearDuration", [ "2025-01-01", "2025-12-31" ]) ]
    end
    let(:cash) do
      { [ "CashAndCashEquivalents", "CurrentYearInstant" ] => 120,
        [ "NetIncreaseDecreaseInCashAndCashEquivalents", "CurrentYearDuration" ] => 20 }
    end

    def extract(source, consolidation = :consolidated)
      Ingestion::StatementExtractor.amounts(Ingestion::Mappings::JgaapGeneral, source: source, consolidation: consolidation)
    end

    it "ReportingPeriodを通したときだけ補完し、Xbrl::Documentを直接渡したときは補完しない" do
      doc = load_document(current + [ context_xml("OpeningCash", [ "2023-12-31" ]) ],
                          cash.merge([ "CashAndCashEquivalents", "OpeningCash" ] => 100))
      expect(extract(bind_period(doc)).to_h).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
      direct = extract(doc)
      expect(direct.to_h).to include("cf.cash_end" => 120)
      expect(direct.to_h).not_to have_key("cf.cash_begin")
    end

    it "期首残を取れていれば、補完で置き換えない" do
      # 期首残（前期末の90）がなければ、CFの式を満たす2023年末の100で補完される
      doc = load_document(current + [ context_xml("Prior1YearInstant", [ "2024-12-31" ]), context_xml("OpeningCash", [ "2023-12-31" ]) ],
                          cash.merge([ "CashAndCashEquivalents", "Prior1YearInstant" ] => 90,
                                     [ "CashAndCashEquivalents", "OpeningCash" ] => 100))
      expect(extract(bind_period(doc)).to_h).to include("cf.cash_begin" => 90, "cf.cash_end" => 120)
    end

    it "単体の区分では、単体のcontextの残高だけで補完する" do
      doc = load_document([
        filing, context_xml("CurrentYearInstant_NonConsolidatedMember", [ "2025-12-31" ], scenario: non_consolidated),
        context_xml("CurrentYearDuration_NonConsolidatedMember", [ "2025-01-01", "2025-12-31" ], scenario: non_consolidated),
        context_xml("ParentOpening", [ "2023-12-31" ], scenario: non_consolidated), context_xml("GroupOpening", [ "2023-12-31" ])
      ], { [ "CashAndCashEquivalents", "CurrentYearInstant_NonConsolidatedMember" ] => 120,
           [ "NetIncreaseDecreaseInCashAndCashEquivalents", "CurrentYearDuration_NonConsolidatedMember" ] => 20,
           [ "CashAndCashEquivalents", "ParentOpening" ] => 100, [ "CashAndCashEquivalents", "GroupOpening" ] => 101 },
         # 連結の101も開示精度の範囲でCFの式を満たすため、連結区分を照合しなければ候補が2つになり補完しない
         decimals: { [ "CashAndCashEquivalents", "GroupOpening" ] => "-1" })
      result = extract(bind_period(doc), :non_consolidated)
      expect(result.to_h).to include("cf.cash_begin" => 100, "cf.cash_end" => 120)
    end

    it "補った期首残の端数は、採った原本の開示精度にする" do
      doc = load_document(current + [ context_xml("OpeningCash", [ "2023-12-31" ]) ],
                          cash.merge([ "CashAndCashEquivalents", "OpeningCash" ] => 100),
                          decimals: { [ "CashAndCashEquivalents", "OpeningCash" ] => "-1" })
      result = extract(bind_period(doc))
      expect(result["cf.cash_begin"]).to eq 100
      expect(result.rounding_errors["cf.cash_begin"]).to eq 10
    end
  end
end

RSpec.describe "期間・連結区分と標準のコンテキストIDの読み替え" do
  it "期間と連結区分の組ごとに、その組を指す標準のIDを求める" do
    pairs = Xbrl::ReportingPeriod::PERIODS.keys.product(Xbrl::ReportingPeriod::CONSOLIDATIONS.values)
    ids = pairs.to_h { |period, consolidation| [ [ period, consolidation ], Xbrl::ReportingPeriod.context_id(period, consolidation) ] }
    expect(ids).to eq(
      [ :instant, :consolidated ] => "CurrentYearInstant",
      [ :duration, :consolidated ] => "CurrentYearDuration",
      [ :prior_instant, :consolidated ] => "Prior1YearInstant",
      [ :instant, :non_consolidated ] => "CurrentYearInstant_NonConsolidatedMember",
      [ :duration, :non_consolidated ] => "CurrentYearDuration_NonConsolidatedMember",
      [ :prior_instant, :non_consolidated ] => "Prior1YearInstant_NonConsolidatedMember")
  end

  it "決めていない期間・連結区分は例外にする" do
    expect { Xbrl::ReportingPeriod.context_id(:instant, nil) }.to raise_error(KeyError)
  end
end
