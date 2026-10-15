require "rails_helper"

# 対応表の検査。対応表は部品の組合せの定数のため、抽出を実行せずに確かめる
# （抽出を実行して出力と参照するタグを観測する検査は mapping_consistency_spec）
RSpec.describe Ingestion::Mappings do
  let(:catalog) { FinancialStatements::ItemCatalog }
  let(:formats) { FinancialStatements::Formats }
  let(:qname_pattern) { /\A(#{Xbrl::Document::NS.keys.join("|")}):[A-Za-z0-9]+\z/ }

  # 取得式が読むタグ。記法（取得式のクラス）を足したら、ここにもその式が読むタグを足す
  def qnames_of(expression)
    expressions = Ingestion::Expressions
    case expression
    when expressions::Tag, expressions::Ratio then [ expression.qname ]
    when expressions::Fallback, expressions::Max then expression.entries.flat_map { |entry| qnames_of(entry) }
    when expressions::Sum then expression.tags.flat_map { |tag| qnames_of(tag) }
    # 企業拡張タグを要素名の形で探す。接頭辞は filer_ext に決まっている
    when expressions::FilerExtension then []
    when expressions::JgaapOwnersEquity
      equity = expressions::JgaapOwnersEquity
      [ *equity::SHAREHOLDERS, *equity::ADJUSTMENTS, equity::NET_ASSETS, *equity::EXCLUDED ]
    else raise "#{expression.class} が読むタグを qnames_of に足す"
    end
  end

  described_class::ALL.each do |mapping|
    describe mapping.format do
      let(:entries) { mapping.sections.flat_map(&:entries) }
      let(:codes) { entries.map(&:code) }

      it "すべての科目がカタログにあり、期首の科目を書いていない（期首の科目はカタログから決まる）" do
        expect(codes).not_to be_empty
        expect(codes - catalog::ALL).to be_empty
        expect(codes & catalog.opening_codes).to be_empty
      end

      it "同じ科目を2つの部品に書いていない" do
        expect(codes).to eq codes.uniq
      end

      it "通常の取得候補と差し替えのときだけ使う候補のタグが、すべて「既知の接頭辞:要素名」の形" do
        qnames = entries.flat_map { |entry| [ entry.expression, *entry.replacements ].flat_map { |expression| qnames_of(expression) } }
        expect(qnames).not_to be_empty
        expect(qnames).to all(match(qname_pattern))
      end
    end
  end

  it "公表ROEのタグが、すべて「既知の接頭辞:要素名」の形" do
    qnames = described_class::DisclosedRoe::EXPRESSIONS.values.flat_map { |expression| qnames_of(expression) }
    expect(qnames).to all(match(qname_pattern))
  end

  it "unsupported以外のすべての形式に、対応表とBS・PLのBuilderがある" do
    expect(described_class::ALL.map(&:format)).to match_array(formats::ALL - [ formats::UNSUPPORTED ])
    (formats::ALL - [ formats::UNSUPPORTED ]).each do |format|
      expect(described_class.for(format)).to have_attributes(format: format)
      expect([ Charts::BuilderRegistry::BS[format], Charts::BuilderRegistry::PL[format] ]).to all(be_present), format
    end
    expect(described_class.for(formats::UNSUPPORTED)).to be_nil
  end
end
