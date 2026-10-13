module Ingestion
  # 形式→Extractorの対応。形式名の一覧は FinancialStatements::Formats にあり、ここの形式名と ALL はその値を指す。
  # 新しい形式に対応するときの手順全体は docs/guide を参照
  module FormatRegistry
    JGAAP_GENERAL   = FinancialStatements::Formats::JGAAP_GENERAL
    JGAAP_BANK      = FinancialStatements::Formats::JGAAP_BANK
    JGAAP_INSURANCE = FinancialStatements::Formats::JGAAP_INSURANCE
    IFRS_CLASSIFIED = FinancialStatements::Formats::IFRS_CLASSIFIED
    IFRS_LIQUIDITY  = FinancialStatements::Formats::IFRS_LIQUIDITY
    IFRS_SUMMARY    = FinancialStatements::Formats::IFRS_SUMMARY
    USGAAP_SUMMARY  = FinancialStatements::Formats::USGAAP_SUMMARY
    UNSUPPORTED     = FinancialStatements::Formats::UNSUPPORTED

    EXTRACTORS = {
      JGAAP_GENERAL   => Extractors::JgaapGeneral,
      JGAAP_BANK      => Extractors::JgaapBank,
      JGAAP_INSURANCE => Extractors::JgaapInsurance,
      IFRS_CLASSIFIED => Extractors::IfrsClassified,
      IFRS_LIQUIDITY  => Extractors::IfrsLiquidity,
      IFRS_SUMMARY    => Extractors::IfrsSummary,
      USGAAP_SUMMARY  => Extractors::UsgaapSummary
    }.freeze

    ALL = FinancialStatements::Formats::ALL

    def self.extractor_for(format) = EXTRACTORS[format] # unsupportedはnil
  end
end
