require "rails_helper"

# 科目カタログの期間と期首の科目が、Extractorが値を引くコンテキストと取得式に一致することを担保する
# （一致していれば、Extractorが期間と期首の科目をカタログから引くように変えても抽出結果は変わらない）。
# mapping_consistency_spec と同じく、マッピング定数を読まずに extract を走らせて出力を観測する
RSpec.describe "Extractorが値を引く期間と科目カタログの整合" do
  # 要素名の形で探す企業拡張タグの記法も、値を返して科目コードを生成させる
  def filer_names = Set.new(%w[BusinessRevenueSummaryOfBusinessResults OperatingRevenuesIFRSSummaryOfBusinessResults])

  # タグごとに違う金額。どのタグから作った値かを、金額で見分けられるようにする
  let(:amount_by_tag) { Hash.new { |amounts, qname| amounts[qname] = amounts.size + 1 } }

  # 1つのコンテキストのタグにだけ値がある書類
  def xbrl_with_values_only_in(context)
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) { |qname, queried| amount_by_tag[qname] if queried == context }
      allow(xbrl).to receive(:rounding_error).and_return(nil)
      allow(xbrl).to receive(:element_names).and_return(filer_names)
      allow(xbrl).to receive(:text).and_return(nil)
    end
  end

  def extract(extractor_class, context) = extractor_class.new(xbrl_with_values_only_in(context), "").extract

  let(:catalog) { FinancialStatements::ItemCatalog::ITEMS.index_by(&:code) }

  Ingestion::FormatRegistry::EXTRACTORS.each do |format, extractor_class|
    describe format do
      it "当期末の値から作る科目は、カタログで期首の科目でない時点の科目" do
        codes = extract(extractor_class, "CurrentYearInstant").keys
        expect(codes).not_to be_empty
        expect(codes.map { |code| catalog.fetch(code) }).to all(have_attributes(period: :instant, opening?: false))
      end

      it "当期の値から作る科目は、カタログで期間の科目" do
        codes = extract(extractor_class, "CurrentYearDuration").keys
        expect(codes).not_to be_empty
        expect(codes.map { |code| catalog.fetch(code) }).to all(have_attributes(period: :duration))
      end

      it "前期末の値から作る科目は、当期末の値から作る科目のカタログの期首の科目で、その科目と同じタグから引く" do
        current = extract(extractor_class, "CurrentYearInstant")
        prior = extract(extractor_class, "Prior1YearInstant")
        openings = catalog.values.select { |item| item.opening? && current.key?(item.opening_of) }
        expect(prior.keys).to match_array(openings.map(&:code))
        openings.each { |item| expect(prior[item.code]).to eq(current[item.opening_of]), item.code }
      end
    end
  end
end
