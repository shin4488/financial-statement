require "rails_helper"

# 取込はinsert_all!（モデルバリデーションを通らない）のため、
# 「対応表から抽出し得る科目コードは必ず科目カタログに存在する」ことをここで担保する。
# 対応表の定数を読むのではなく、抽出（Ingestion::StatementExtractor.amounts）を実際に走らせて出力・参照タグを観測する
# （書き方が変わってもspecを直さずに済み、対応表に無い生成経路も漏れなく対象になる）
RSpec.describe "対応表から抽出した科目と科目カタログの整合" do
  # 要素名の形で探す企業拡張タグの記法も、値を返して科目コードを生成させる
  def filer_names = Set.new(%w[BusinessRevenueSummaryOfBusinessResults OperatingRevenuesIFRSSummaryOfBusinessResults])

  def extract(mapping, source) = Ingestion::StatementExtractor.amounts(mapping, source: source, consolidation: :consolidated)

  # 全タグに値がある書類: 抽出が生成し得る全キーを一度に出力させる
  def xbrl_with_every_tag
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money).and_return(1)
      allow(xbrl).to receive(:rounding_error).and_return(nil)
      allow(xbrl).to receive(:element_names).and_return(filer_names)
    end
  end

  # 全タグが無い書類: フォールバックが途中で止まらず、参照し得る全タグの qname を観測できる
  def xbrl_recording_qnames(recorded)
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:element_names).and_return(filer_names)
      allow(xbrl).to receive(:text).and_return(nil)
      allow(xbrl).to receive(:money) do |qname, _context|
        recorded << qname
        nil
      end
    end
  end

  Ingestion::Mappings::ALL.each do |mapping|
    describe mapping.format do
      it "生成し得る全科目コードが科目カタログに存在する" do
        codes = extract(mapping, xbrl_with_every_tag).codes
        expect(codes).not_to be_empty
        expect(codes - FinancialStatements::ItemCatalog::ALL).to be_empty
      end

      it "参照する全タグが解決可能なqname（既知の名前空間prefix:LocalName）である" do
        recorded = []
        extract(mapping, xbrl_recording_qnames(recorded))
        expect(recorded).not_to be_empty
        expect(recorded.uniq).to all(match(/\A(#{Xbrl::Document::NS.keys.join("|")}):[A-Za-z0-9]+\z/))
      end
    end
  end
end
