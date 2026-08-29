require "rails_helper"

# 取込はinsert_all!（モデルバリデーションを通らない）のため、
# 「Extractorが生成し得る科目コードは必ずレジストリに存在する」ことをここで担保する。
# マッピング定数を読み替えるのではなく、extract（公開API）を実際に走らせて出力・参照タグを観測する
# （書き方が変わってもspecを直さずに済み、マッピング表に無い生成経路も漏れなく対象になる）
RSpec.describe "Extractorの出力とItemCodesレジストリの整合" do
  # 全タグに値がある書類: extractが生成し得る全キーを一度に出力させる
  def xbrl_with_every_tag
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money).and_return(1)
    end
  end

  # 全タグが無い書類: フォールバックが途中で止まらず、参照し得る全タグの qname を観測できる
  def xbrl_recording_qnames(recorded)
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money) do |qname, _context|
        recorded << qname
        nil
      end
    end
  end

  Ingestion::FormatRegistry::EXTRACTORS.each do |format, extractor_class|
    describe format do
      it "生成し得る全科目コードがItemCodesレジストリに存在する" do
        codes = extractor_class.new(xbrl_with_every_tag, "").extract.keys
        expect(codes).not_to be_empty
        expect(codes - FinancialStatements::ItemCodes::ALL).to be_empty
      end

      it "参照する全タグが解決可能なqname（既知の名前空間prefix:LocalName）である" do
        recorded = []
        extractor_class.new(xbrl_recording_qnames(recorded), "").extract
        expect(recorded).not_to be_empty
        expect(recorded.uniq).to all(match(/\A(#{Xbrl::Document::NS.keys.join("|")}):[A-Za-z0-9]+\z/))
      end
    end
  end
end
