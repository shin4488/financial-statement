module Ingestion
  # 対応表。形式ごとに、科目コードから取得式を引く表（Mappings::Mapping）を、名前を付けた部品（Mappings::Section）の組合せで作る。
  # 部品も形式の対応表も、ファイル名に対応する名前の定数を1ファイルに1つ置く（mappings/）
  module Mappings
    ALL = [ JgaapGeneral, JgaapBank, JgaapInsurance, IfrsClassified, IfrsLiquidity, IfrsSummary, UsgaapSummary ].freeze

    # 形式の対応表。対応する形式がない（unsupported）ときは nil
    def self.for(format) = ALL.find { |mapping| mapping.format == format }
  end
end
