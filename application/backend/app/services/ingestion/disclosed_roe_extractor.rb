module Ingestion
  # 公表ROEを取る。タグは対応表の部品 Mappings::DisclosedRoe が区分の会計基準で選ぶ
  class DisclosedRoeExtractor
    # consolidation は Extractors::Base::CONSOLIDATED / NON_CONSOLIDATED
    def self.extract(xbrl, accounting_standard:, consolidation:)
      Mappings::DisclosedRoe.amount(xbrl, accounting_standard: accounting_standard,
                                          consolidation: Xbrl::ReportingPeriod::CONSOLIDATIONS[consolidation])
    end
  end
end
