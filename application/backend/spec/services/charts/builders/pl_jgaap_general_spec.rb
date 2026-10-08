require "rails_helper"

RSpec.describe Charts::Builders::PlJgaapGeneral do
  # 取込で保存する科目と同じく、各金額に表示単位の端数（1単位）を持たせる
  def amounts(values)
    FinancialStatements::Amounts.new.tap do |items|
      items.merge!(values)
      values.each_key { |code| items.rounding_errors[code] = 1.to_d }
    end
  end

  def keys(chart) = chart.bars.map { |bar| bar.segments.map(&:key) }

  describe "黒字" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 300,
        "pl.operating_profit" => 100 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方[原価, 販管費, 営業利益] / 貸方[売上] になる" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
      expect(credit.segments.map(&:key)).to eq %w[revenue]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "営業損失" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 800, "pl.sga" => 400,
        "pl.operating_profit" => -200 }
    end
    subject(:chart) { described_class.new(items).build }

    it "営業損失は貸方に符号付き実値で積まれる" do
      debit, credit = chart.bars
      loss = credit.segments.find { |s| s.key == "operatingLoss" }
      expect(loss.amount).to eq 200
      expect(loss.signed_amount).to eq(-200)
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "原価・販管費がない持株会社型" do
    it "売上と営業利益だけで描画される（開示のない費用科目は積まない）" do
      chart = described_class.new({ "pl.revenue" => 1_000, "pl.operating_profit" => 1_000 }).build
      expect(chart.renderable).to be true
      debit, = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[operatingProfit]
    end
  end

  describe "費用の構成が業種で異なる" do
    it "証券（営業収益−金融費用−販管費=営業利益）は金融費用を原価の位置に積む" do
      chart = described_class.new({ "pl.revenue" => 24_579, "pl.financial_expenses" => 71,
                                    "pl.sga" => 18_347, "pl.operating_profit" => 6_160 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[financialExpenses sga operatingProfit]
    end

    it "営業費用一括型（電気・特定金融など）は営業費用1本で描く" do
      chart = described_class.new({ "pl.revenue" => 6_328_574, "pl.operating_expenses" => 5_990_884,
                                    "pl.operating_profit" => 337_689 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[operatingExpenses operatingProfit]
    end

    it "内訳と一括の営業費用が併記されていれば内訳（原価・販管費）で描く（重複計上しない）" do
      chart = described_class.new(amounts("pl.revenue" => 1_086_179, "pl.cost_of_sales" => 744_710, "pl.sga" => 238_275,
                                          "pl.operating_expenses" => 982_986, "pl.operating_profit" => 103_193)).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
    end

    it "内訳では貸借が合わず一括の営業費用でなら合う企業（原価が営業費用の内訳として併記される特定金融など）は一括で描く" do
      chart = described_class.new({ "pl.revenue" => 8_779, "pl.cost_of_sales" => 272,
                                    "pl.operating_expenses" => 2_959, "pl.operating_profit" => 5_819 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[operatingExpenses operatingProfit]
    end

    it "売上原価と原価控除後の営業費用を開示する商品先物取引業は [原価, 営業費用] で描く（単位: 千円）" do
      chart = described_class.new({ "pl.revenue" => 5_047_625, "pl.cost_of_sales" => 1_654_880,
                                    "pl.operating_expenses" => 3_210_396, "pl.operating_profit" => 182_347 }).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[costOfSales operatingExpenses operatingProfit]
    end
  end

  describe "費用の組み合わせの選び方（左右が端数の範囲で一致する組み合わせを優先する）" do
    it "信販会社は、差が1割以内の販管費より、左右が一致する営業費用（販管費と金融費用を含む合計）で描く（単位: 百万円）" do
      # ジャックス 2020年3月期: 販管費127,491＋営業利益16,506は売上158,610と9%ずれる
      builder = described_class.new(amounts("pl.revenue" => 158_610, "pl.sga" => 127_491,
                                            "pl.operating_expenses" => 142_104, "pl.operating_profit" => 16_506))
      aggregate_failures do
        expect(keys(builder.build)).to eq [ %w[operatingExpenses operatingProfit], %w[revenue] ]
        expect(builder.mismatch).to be_nil
      end
    end

    it "原価に当たる費用を営業費用として開示し、別に販管費を並べる会社は、営業費用と販管費を積む（単位: 百万円）" do
      # 燦ホールディングス 2025年3月期: 営業費用24,216＋販管費3,246＋営業利益4,521＝31,983、売上31,984
      builder = described_class.new(amounts("pl.revenue" => 31_984, "pl.sga" => 3_246,
                                            "pl.operating_expenses" => 24_216, "pl.operating_profit" => 4_521))
      chart = builder.build
      segments = chart.bars.first.segments.to_h { |s| [ s.key, s ] }
      aggregate_failures do
        expect(keys(chart)).to eq [ %w[operatingExpenses sga operatingProfit], %w[revenue] ]
        expect(segments["operatingExpenses"]).to have_attributes(color_role: "expense1", tooltip_label: "営業費用（販管費を除く）")
        expect(segments["sga"].color_role).to eq "expense2"
        expect(builder.mismatch).to be_nil
      end
    end

    it "営業費用が販管費を含む合計の会社は、販管費を二重に積まない（単位: 百万円）" do
      # 燦ホールディングス単体: 営業費用4,152＋営業利益2,631＝売上6,783
      chart = described_class.new(amounts("pl.revenue" => 6_783, "pl.sga" => 1_722,
                                          "pl.operating_expenses" => 4_152, "pl.operating_profit" => 2_631)).build
      expect(keys(chart)).to eq [ %w[operatingExpenses operatingProfit], %w[revenue] ]
    end

    it "営業費用と販管費の組み合わせは、左右の差が1割以内でも端数を超えてずれれば使わない" do
      chart = described_class.new(amounts("pl.revenue" => 1_000, "pl.sga" => 250,
                                          "pl.operating_expenses" => 600, "pl.operating_profit" => 100)).build
      expect(chart.renderable).to be false
    end

    it "どの組み合わせも端数の範囲で一致しなければ、差が1割以内の組み合わせで描き、照合に使った金額を返す" do
      builder = described_class.new(amounts("pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250,
                                            "pl.operating_profit" => 100))
      aggregate_failures do
        expect(keys(builder.build)).to eq [ %w[costOfSales sga operatingProfit], %w[revenue] ]
        expect(builder.mismatch).to eq("pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250,
                                       "pl.operating_profit" => 100)
      end
    end

    it "描かないときは、照合の不一致を返さない" do
      builder = described_class.new(amounts("pl.revenue" => 2_478_950, "pl.sga" => 748_887, "pl.operating_profit" => 108_348))
      aggregate_failures do
        expect(builder.build.renderable).to be false
        expect(builder.mismatch).to be_nil
      end
    end
  end

  describe "売上0（売上の行が「－」）" do
    it "費用の合計と営業損失が一致すれば、借方に費用、貸方に営業損失を積み、比率の分母を営業損失にする（単位: 百万円）" do
      # ヘリオス 2019年12月期: 販管費4,271、営業損失4,271
      chart = described_class.new(amounts("pl.revenue" => 0, "pl.sga" => 4_271, "pl.operating_profit" => -4_271)).build
      debit, credit = chart.bars
      aggregate_failures do
        expect(chart.renderable).to be true
        expect(debit.segments.map { |s| [ s.key, s.amount, s.ratio ] }).to eq [ [ "sga", 4_271, 100.0 ] ]
        expect(credit.segments.map { |s| [ s.key, s.amount, s.signed_amount, s.ratio ] })
          .to eq [ [ "operatingLoss", 4_271, -4_271, -100.0 ] ]
      end
    end

    it "費用の合計と営業損失が合わなければ、費用を差額で求めずに描かない" do
      chart = described_class.new(amounts("pl.revenue" => 0, "pl.sga" => 3_000, "pl.operating_profit" => -4_271)).build
      expect(chart.renderable).to be false
    end
  end

  describe "営業費用の色とツールチップ表示名" do
    it "一括型（原価を含む合計）では原価と同じ色になり、ツールチップは原価込みであることを補足する" do
      chart = described_class.new({ "pl.revenue" => 1_000, "pl.operating_expenses" => 900,
                                    "pl.operating_profit" => 100 }).build
      oe = chart.bars.first.segments.find { |s| s.key == "operatingExpenses" }
      expect(oe.color_role).to eq "expense1"
      expect(oe.label).to eq "営業費用" # バー内ラベルは折り返し・見切れが起きるため補足を足さない
      expect(oe.tooltip_label).to eq "営業費用（原価を含む）"
    end

    it "原価+営業費用型（原価控除後の費用）では販管費と同じ色になり、ツールチップは原価を除くことを補足する" do
      chart = described_class.new({ "pl.revenue" => 1_000, "pl.cost_of_sales" => 300,
                                    "pl.operating_expenses" => 600, "pl.operating_profit" => 100 }).build
      segments = chart.bars.first.segments.to_h { |s| [ s.key, s ] }
      expect(segments["costOfSales"].color_role).to eq "expense1"
      expect(segments["costOfSales"].tooltip_label).to be_nil
      expect(segments["operatingExpenses"].color_role).to eq "expense2"
      expect(segments["operatingExpenses"].tooltip_label).to eq "営業費用（原価を除く）"
    end
  end

  it "売上か営業利益が欠ければunrenderable" do
    expect(described_class.new({ "pl.operating_profit" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 0, "pl.operating_profit" => 1 }).build.renderable).to be false
  end

  describe "貸借の1割超乖離" do
    it "原価が科目ゆれで取れていない企業はunrenderable（単位: 円）" do
      chart = described_class.new({
        "pl.revenue" => 2_478_950_000, "pl.sga" => 748_887_000,
        "pl.operating_profit" => 108_348_000 }).build
      expect(chart.renderable).to be false
    end

    it "乖離が1割以内なら描画される" do
      chart = described_class.new({
        "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250,
        "pl.operating_profit" => 100 }).build
      expect(chart.renderable).to be true
    end
  end
end
