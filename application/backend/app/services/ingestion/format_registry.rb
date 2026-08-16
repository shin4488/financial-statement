module Ingestion
  # 表示形式（presentation_format）の一覧と、形式→Extractorの対応。
  # 新形式の追加はここに定数1つ + EXTRACTORSに1行 + Extractorクラス1つ（+ Builder）で完結する
  module FormatRegistry
    JGAAP_GENERAL   = "jgaap_general"
    JGAAP_BANK      = "jgaap_bank"
    IFRS_CLASSIFIED = "ifrs_classified"
    IFRS_LIQUIDITY  = "ifrs_liquidity"
    UNSUPPORTED     = "unsupported"
    ALL = [ JGAAP_GENERAL, JGAAP_BANK, IFRS_CLASSIFIED, IFRS_LIQUIDITY, UNSUPPORTED ].freeze

    EXTRACTORS = {
      JGAAP_GENERAL   => Extractors::JgaapGeneral,
      JGAAP_BANK      => Extractors::JgaapBank,
      IFRS_CLASSIFIED => Extractors::IfrsClassified,
      IFRS_LIQUIDITY  => Extractors::IfrsLiquidity
    }.freeze

    def self.extractor_for(format) = EXTRACTORS[format] # unsupportedはnil
  end
end
