require "rails_helper"

# 取得式を、期間と連結区分のシンボルで評価する。記法ごとの取り方は mappings/notation_spec が対応表からの抽出で確かめる
RSpec.describe Ingestion::Expressions do
  # facts: { [qname, 標準のコンテキストID] => 値 } を書いたXBRL。decimals は開示の精度（"0"なら端数の上限は1、"-1"なら10）
  def source_with(facts = {}, decimals: {}) = synthetic_xbrl_document(facts: facts, decimals: decimals)

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

  it "期間と連結区分の組で、その組を指す標準のコンテキストIDの値を引く" do
    source = source_with({ [ "jppfs_cor:A", "Prior1YearInstant_NonConsolidatedMember" ] => 100, [ "jppfs_cor:A", "CurrentYearInstant" ] => 200 },
                         decimals: { [ "jppfs_cor:A", "Prior1YearInstant_NonConsolidatedMember" ] => "0" })
    aggregate_failures do
      expect(tag("jppfs_cor:A").evaluate(source, period: :prior_instant, consolidation: :non_consolidated))
        .to eq described_class::Measured.new(100, 1.to_d)
      expect(tag("jppfs_cor:A").amount(source, period: :instant, consolidation: :consolidated)).to eq 200
    end
  end

  describe "#amount" do
    it "金額と端数の組の評価と同じ金額を返す" do
      facts = { [ "jppfs_cor:A", context ] => 500, [ "jppfs_cor:B", context ] => 500, [ "jppfs_cor:C", context ] => 70,
                [ "filer_ext:XSummaryOfBusinessResults", context ] => 9 }
      source = source_with(facts)
      expressions = [
        described_class.sum("jppfs_cor:A", "jppfs_cor:B", distinct_amounts: true),
        described_class.sum("jppfs_cor:A", "jppfs_cor:D", all_present: true),
        described_class.max("jppfs_cor:C", described_class.sum("jppfs_cor:A", "jppfs_cor:C")),
        described_class.filer_ext(/SummaryOfBusinessResults\z/),
        described_class.wrap([ "jppfs_cor:D", "jppfs_cor:C" ]),
        described_class.wrap([ "jppfs_cor:D", "jppfs_cor:E" ])
      ]
      expect(expressions.map { |expression| expression.amount(source, **duration) })
        .to eq [ 500, nil, 570, 9, 70, nil ]
      expect(expressions.map { |expression| expression.evaluate(source, **duration)&.amount }).to eq [ 500, nil, 570, 9, 70, nil ]
    end
  end

  describe "フォールバック" do
    let(:fallback) { described_class.wrap([ "jppfs_cor:A", "jppfs_cor:B" ]) }

    it "先に取れた候補の金額と端数を組にする" do
      source = source_with({ [ "jppfs_cor:B", context ] => 50 }, decimals: { [ "jppfs_cor:B", context ] => "0" })
      expect(fallback.evaluate(source, **duration)).to eq described_class::Measured.new(50, 1.to_d)
    end

    it "どの候補からも金額が取れず、行はあるが値が空の候補があるときだけ空とする" do
      aggregate_failures do
        expect(fallback.blank?(source_with({ [ "jppfs_cor:B", context ] => "" }), **duration)).to be true
        expect(fallback.blank?(source_with({ [ "jppfs_cor:A", context ] => 10, [ "jppfs_cor:B", context ] => "" }), **duration)).to be false
        expect(fallback.blank?(source_with, **duration)).to be false
      end
    end
  end

  it "最大値は、同じ金額の候補が複数あれば先頭の候補の端数を使う" do
    facts = { [ "jppfs_cor:A", context ] => 100, [ "jppfs_cor:B", context ] => 60, [ "jppfs_cor:C", context ] => 40 }
    decimals = { [ "jppfs_cor:A", context ] => "0", [ "jppfs_cor:B", context ] => "-1", [ "jppfs_cor:C", context ] => "-1" }
    max = described_class.max("jppfs_cor:A", described_class.sum("jppfs_cor:B", "jppfs_cor:C"))
    expect(max.evaluate(source_with(facts, decimals: decimals), **duration)).to eq described_class::Measured.new(100, 1.to_d)
  end

  describe "比率" do
    let(:ratio) { described_class.ratio("jpcrp_cor:Roe") }

    it "有限の数値の文字列を値にし、端数は不明とする" do
      source = source_with({ [ "jpcrp_cor:Roe", context ] => "0.0706" })
      expect(ratio.evaluate(source, **duration)).to eq described_class::Measured.new(0.0706.to_d, nil)
    end

    [ "", "abc", "Infinity", "1e999" ].each do |value|
      it "空・不正・非有限の値#{value.inspect}は取らない" do
        source = source_with({ [ "jpcrp_cor:Roe", context ] => value })
        expect([ ratio.amount(source, **duration), ratio.evaluate(source, **duration) ]).to eq [ nil, nil ]
      end
    end

    it "行はあるが値が空なら空とする" do
      aggregate_failures do
        expect(ratio.blank?(source_with({ [ "jpcrp_cor:Roe", context ] => "" }), **duration)).to be true
        expect(ratio.blank?(source_with({ [ "jpcrp_cor:Roe", context ] => "0.1" }), **duration)).to be false
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
      decimals = { [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => "0",
                   [ "jppfs_cor:AccumulatedOtherComprehensiveIncome", "CurrentYearInstant" ] => "-1" }
      source = source_with(facts, decimals: decimals)
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
      source = source_with({ [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => "" })
      expect(equity.blank?(source, **instant)).to be false
    end
  end

  describe ".statement_candidates" do
    it "フォールバックは要素を、ほかの取得式はそれ自身を候補にする" do
      sum = described_class.sum("t:A", "t:B")
      aggregate_failures do
        expect(described_class.statement_candidates(described_class.wrap([ "t:A", sum ]))).to eq [ tag("t:A"), sum ]
        expect(described_class.statement_candidates(sum)).to eq [ sum ]
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
