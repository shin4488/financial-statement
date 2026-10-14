require "rails_helper"

# 取得式を、期間と連結区分のシンボルで評価する。記法ごとの取り方は extractors/base_spec が旧い入口から確かめる
RSpec.describe Ingestion::Expressions do
  # facts・errors・texts: { [qname, 標準のコンテキストID] => 値 }。texts にないタグの文字列は金額から作る
  def source_with(facts = {}, errors: {}, texts: {}, filer_names: [])
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, context| facts[[ qname, context ]] }
      allow(xbrl).to receive(:rounding_error) { |qname, context| errors[[ qname, context ]] }
      allow(xbrl).to receive(:text) { |qname, context| texts.fetch([ qname, context ]) { facts[[ qname, context ]]&.to_s } }
      allow(xbrl).to receive(:element_names).with("filer_ext").and_return(Set.new(filer_names))
    end
  end

  let(:duration) { { period: :duration, consolidation: :consolidated } }
  let(:context) { "CurrentYearDuration" }

  def tag(qname) = described_class::Tag.new(qname)

  describe ".wrap" do
    it "単一タグの文字列はTag、配列は要素を揃えたフォールバック、取得式はそのまま" do
      sum = described_class.sum("t:B", "t:C")
      aggregate_failures do
        expect(described_class.wrap("t:A")).to eq tag("t:A")
        expect(described_class.wrap([ "t:A", sum ])).to eq described_class::Fallback.new([ tag("t:A"), sum ])
        expect(described_class.wrap(sum)).to be sum
      end
    end
  end

  it "期間と連結区分の組を、それを指す標準のコンテキストIDで問い合わせる" do
    source = source_with({ [ "t:A", "Prior1YearInstant_NonConsolidatedMember" ] => 100, [ "t:A", "CurrentYearInstant" ] => 200 },
                         errors: { [ "t:A", "Prior1YearInstant_NonConsolidatedMember" ] => 1.to_d })
    aggregate_failures do
      expect(tag("t:A").evaluate(source, period: :prior_instant, consolidation: :non_consolidated))
        .to eq described_class::Measured.new(100, 1.to_d)
      expect(tag("t:A").amount(source, period: :instant, consolidation: :consolidated)).to eq 200
    end
  end

  describe "#amount" do
    it "金額だけを問い合わせ、端数を読まない（金額にしか答えないXBRLでも評価できる）" do
      xbrl = instance_double(Xbrl::Document)
      allow(xbrl).to receive(:money) { |qname, _context| { "t:B" => 30, "t:C" => 20 }[qname] }
      expression = described_class.wrap([ "t:A", described_class.max("t:B", described_class.sum("t:C", "t:D")) ])
      expect(expression.amount(xbrl, **duration)).to eq 30
    end

    it "金額と端数の組の評価と同じ金額を返す" do
      facts = { [ "t:A", context ] => 500, [ "t:B", context ] => 500, [ "t:C", context ] => 70,
                [ "filer_ext:XSummaryOfBusinessResults", context ] => 9 }
      source = source_with(facts, filer_names: %w[XSummaryOfBusinessResults])
      expressions = [
        described_class.sum("t:A", "t:B", distinct_amounts: true),
        described_class.sum("t:A", "t:D", all_present: true),
        described_class.max("t:C", described_class.sum("t:A", "t:C")),
        described_class.filer_ext(/SummaryOfBusinessResults\z/),
        described_class.wrap([ "t:D", "t:C" ]),
        described_class.wrap([ "t:D", "t:E" ])
      ]
      expect(expressions.map { |expression| expression.amount(source, **duration) })
        .to eq [ 500, nil, 570, 9, 70, nil ]
      expect(expressions.map { |expression| expression.evaluate(source, **duration)&.amount }).to eq [ 500, nil, 570, 9, 70, nil ]
    end
  end

  describe "フォールバック" do
    let(:fallback) { described_class.wrap([ "t:A", "t:B" ]) }

    it "先に取れた候補の金額と端数を組にする" do
      source = source_with({ [ "t:B", context ] => 50 }, errors: { [ "t:B", context ] => 1.to_d })
      expect(fallback.evaluate(source, **duration)).to eq described_class::Measured.new(50, 1.to_d)
    end

    it "どの候補からも金額が取れず、行はあるが値が空の候補があるときだけ空とする" do
      aggregate_failures do
        expect(fallback.blank?(source_with(texts: { [ "t:B", context ] => "" }), **duration)).to be true
        expect(fallback.blank?(source_with({ [ "t:A", context ] => 10 }, texts: { [ "t:B", context ] => "" }), **duration)).to be false
        expect(fallback.blank?(source_with, **duration)).to be false
      end
    end
  end

  it "最大値は、同じ金額の候補が複数あれば先頭の候補の端数を使う" do
    facts = { [ "t:A", context ] => 100, [ "t:B", context ] => 60, [ "t:C", context ] => 40 }
    errors = { [ "t:A", context ] => 1.to_d, [ "t:B", context ] => 10.to_d, [ "t:C", context ] => 10.to_d }
    max = described_class.max("t:A", described_class.sum("t:B", "t:C"))
    expect(max.evaluate(source_with(facts, errors: errors), **duration)).to eq described_class::Measured.new(100, 1.to_d)
  end

  describe "比率" do
    let(:ratio) { described_class.ratio("t:Roe") }

    it "有限の数値の文字列を値にし、端数は不明とする" do
      source = source_with(texts: { [ "t:Roe", context ] => "0.0706" })
      expect(ratio.evaluate(source, **duration)).to eq described_class::Measured.new(0.0706.to_d, nil)
    end

    [ "", "abc", "Infinity", "1e999" ].each do |value|
      it "空・不正・非有限の値#{value.inspect}は取らない" do
        source = source_with(texts: { [ "t:Roe", context ] => value })
        expect([ ratio.amount(source, **duration), ratio.evaluate(source, **duration) ]).to eq [ nil, nil ]
      end
    end

    it "行はあるが値が空なら空とする" do
      aggregate_failures do
        expect(ratio.blank?(source_with(texts: { [ "t:Roe", context ] => "" }), **duration)).to be true
        expect(ratio.blank?(source_with(texts: { [ "t:Roe", context ] => "0.1" }), **duration)).to be false
      end
    end
  end

  describe "自己資本（日本基準）" do
    let(:equity) { described_class::JgaapOwnersEquity.new }
    let(:instant) { { period: :instant, consolidation: :consolidated } }
    let(:facts) do
      { [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 100,
        [ "jppfs_cor:AccumulatedOtherComprehensiveIncome", "CurrentYearInstant" ] => -20 }
    end

    it "株主資本と評価・換算差額等を足し、端数の上限も足す" do
      errors = { [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 1.to_d,
                 [ "jppfs_cor:AccumulatedOtherComprehensiveIncome", "CurrentYearInstant" ] => 10.to_d }
      source = source_with(facts, errors: errors)
      aggregate_failures do
        expect(equity.evaluate(source, **instant)).to eq described_class::Measured.new(80, 11.to_d)
        expect(equity.amount(source, **instant)).to eq 80
      end
    end

    it "精度が不明なタグがあれば端数は不明、株主資本がなければ取らない" do
      aggregate_failures do
        expect(equity.evaluate(source_with(facts), **instant)).to eq described_class::Measured.new(80, nil)
        expect(equity.evaluate(source_with, **instant)).to be_nil
      end
    end

    it "複数のタグから求める科目のため、表の「－」を確かめる対象にしない" do
      source = source_with(texts: { [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => "" })
      expect(equity.blank?(source, **instant)).to be false
    end
  end

  describe ".candidates・.statement_candidates" do
    it "フォールバックは要素を、ほかの取得式はそれ自身を候補にする" do
      sum = described_class.sum("t:A", "t:B")
      aggregate_failures do
        expect(described_class.candidates(described_class.wrap([ "t:A", sum ]))).to eq [ tag("t:A"), sum ]
        expect(described_class.candidates(sum)).to eq [ sum ]
      end
    end

    it "本表の候補は、経営指標の要約の単一タグだけを除き、合算・最大値の中の要約のタグは除かない" do
      sum = described_class.sum("jpcrp_cor:NetSalesSummaryOfBusinessResults", "t:B")
      max = described_class.max("jpcrp_cor:NetSalesSummaryOfBusinessResults", "t:B")
      expression = described_class.wrap([ "t:A", "jpcrp_cor:NetSalesSummaryOfBusinessResults", sum, max ])
      expect(described_class.statement_candidates(expression)).to eq [ tag("t:A"), sum, max ]
    end
  end
end
