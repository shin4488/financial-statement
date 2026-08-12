require "rails_helper"

# 取込はinsert_all!（モデルバリデーションを通らない）のため、
# 「Extractorが生成し得る科目コードは必ずレジストリに存在する」ことをここで担保する
RSpec.describe "ExtractorマッピングとItemCodesレジストリの整合" do
  # extract_extras で直接putされるコード（マッピング定数に現れない分）
  EXTRA_CODES = {
    Ingestion::Extractors::JgaapGeneral   => %w[cf.cash_begin],
    Ingestion::Extractors::JgaapBank      => %w[cf.cash_begin],
    Ingestion::Extractors::IfrsClassified => %w[cf.cash_begin bs.goodwill_and_intangibles],
    Ingestion::Extractors::IfrsLiquidity  => %w[cf.cash_begin]
  }.freeze

  Ingestion::FormatRegistry::EXTRACTORS.each_value do |extractor_class|
    describe extractor_class.name do
      it "全マッピングキーがレジストリに存在する" do
        codes = extractor_class::INSTANT_MAPPING.keys +
                extractor_class::DURATION_MAPPING.keys +
                EXTRA_CODES.fetch(extractor_class)
        expect(codes - FinancialStatements::ItemCodes::ALL).to be_empty
      end

      it "マッピングのタグ表記が qname（prefix:LocalName）形式である" do
        qnames = (extractor_class::INSTANT_MAPPING.values + extractor_class::DURATION_MAPPING.values)
                 .flat_map { |v| Array(v) }
        expect(qnames).to all(match(/\A(jppfs_cor|jpigp_cor|jpcrp_cor|jpdei_cor):[A-Za-z0-9]+\z/))
      end
    end
  end
end
