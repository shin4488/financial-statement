module Ingestion
  # 表示形式（presentation_format）の一覧と、形式→Extractorの対応。
  # 新しい形式に対応するときの手順全体は docs/guide/03_data_flow.md の「変更ガイド」を参照
  module FormatRegistry
    JGAAP_GENERAL   = "jgaap_general"
    JGAAP_BANK      = "jgaap_bank"
    JGAAP_INSURANCE = "jgaap_insurance"
    IFRS_CLASSIFIED = "ifrs_classified"
    IFRS_LIQUIDITY  = "ifrs_liquidity"
    IFRS_SUMMARY    = "ifrs_summary"
    UNSUPPORTED     = "unsupported"

    EXTRACTORS = {
      JGAAP_GENERAL   => Extractors::JgaapGeneral,
      JGAAP_BANK      => Extractors::JgaapBank,
      JGAAP_INSURANCE => Extractors::JgaapInsurance,
      IFRS_CLASSIFIED => Extractors::IfrsClassified,
      IFRS_LIQUIDITY  => Extractors::IfrsLiquidity,
      IFRS_SUMMARY    => Extractors::IfrsSummary
    }.freeze

    # 形式の正当な値一覧はEXTRACTORSから導出する（別に列挙すると形式追加時に片方を忘れるため）
    ALL = (EXTRACTORS.keys + [ UNSUPPORTED ]).freeze

    def self.extractor_for(format) = EXTRACTORS[format] # unsupportedはnil
  end
end
