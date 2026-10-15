require "rails_helper"

RSpec.describe Ingestion::Mappings::Mapping do
  let(:section) { Ingestion::Mappings::Section }
  let(:expressions) { Ingestion::Expressions }

  def tag(qname) = expressions::Tag.new(qname)
  def item(code, period, expression) = described_class::Item.new(code, period, expression)

  describe "#items" do
    it "科目の期間を科目カタログから決め、期首の科目は期末の科目の取得式で前期末を引く" do
      cash_flow = section.define { item "cf.cash_end", "t:Cash" }
      mapping = described_class.define("test", cash_flow) do
        item "bs.assets", "t:Assets"
        item "pl.revenue", "t:Sales"
      end
      # 自己資本はこの対応表にないため、その期首の科目も作らない
      expect(mapping.items).to match_array [
        item("bs.assets", :instant, tag("t:Assets")), item("bs.assets_begin", :prior_instant, tag("t:Assets")),
        item("pl.revenue", :duration, tag("t:Sales")),
        item("cf.cash_end", :instant, tag("t:Cash")), item("cf.cash_begin", :prior_instant, tag("t:Cash"))
      ]
    end

    it "差し替えのときだけ使う候補は、通常の取得で評価する科目に含めない" do
      mapping = described_class.define("test") { item "pl.revenue", [ "t:Sales" ], replacements: [ "t:SalesAndRent" ] }
      expect(mapping.items).to eq [ item("pl.revenue", :duration, expressions::Fallback.new([ tag("t:Sales") ])) ]
    end
  end

  it "取得式・差し替えのときだけ使う候補・作る科目の一覧を、部品をまたいで引く" do
    equity = section.define { item "bs.equity_attributable_to_owners", "t:Equity" }
    mapping = described_class.define("test", equity) do
      item "pl.revenue", "t:Sales", replacements: [ sum("t:Sales", "t:Rent", all_present: true), "t:Total" ]
    end
    aggregate_failures do
      expect(mapping.expression("bs.equity_attributable_to_owners")).to eq tag("t:Equity")
      expect(mapping.expression("bs.assets")).to be_nil
      expect(mapping.replacements("pl.revenue")).to eq [ expressions.sum("t:Sales", "t:Rent", all_present: true), tag("t:Total") ]
      expect(mapping.replacements("bs.equity_attributable_to_owners")).to eq []
      expect(mapping.item_codes).to match_array %w[bs.equity_attributable_to_owners bs.equity_attributable_to_owners_begin pl.revenue]
      expect(mapping.sections.size).to eq 2
    end
  end

  it "部品の中では、sum・max・filer_ext の記法と、単一タグの文字列・フォールバックの配列で書ける" do
    part = section.define do
      item "pl.sga", sum("t:A", "t:B", distinct_amounts: true)
      item "pl.revenue", max("t:C", "t:D")
      item "pl.summary_revenue", [ "t:E", filer_ext(/Summary\z/) ]
    end
    expect(part.entries.map(&:expression)).to eq [
      expressions.sum("t:A", "t:B", distinct_amounts: true), expressions.max("t:C", "t:D"),
      expressions::Fallback.new([ tag("t:E"), expressions.filer_ext(/Summary\z/) ])
    ]
  end

  describe "読込時の確かめ" do
    let(:assets) { section.define { item "bs.assets", "t:Assets" } }

    it "同じ科目を2つの部品に書くと、後の部品が黙って上書きしないよう例外にする" do
      expect { described_class.define("test", assets) { item "bs.assets", "t:TotalAssets" } }
        .to raise_error(ArgumentError, /test: bs\.assets/)
    end

    it "1つの部品に同じ科目を2回書くと例外にする" do
      define_twice = lambda do
        section.define do
          item "bs.assets", "t:A"
          item "bs.assets", "t:B"
        end
      end
      expect(&define_twice).to raise_error(ArgumentError, /bs\.assets/)
    end

    it "科目カタログにない科目と、カタログから決まる期首の科目は書けない" do
      aggregate_failures do
        expect { described_class.define("test") { item "bs.unknown", "t:A" } }.to raise_error(ArgumentError, /bs\.unknown/)
        expect { described_class.define("test", assets) { item "bs.assets_begin", "t:A" } }.to raise_error(ArgumentError, /bs\.assets_begin/)
      end
    end
  end
end
