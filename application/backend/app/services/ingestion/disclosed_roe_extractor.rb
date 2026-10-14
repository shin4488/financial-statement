module Ingestion
  # 金額の科目に混ぜず、同じ年度・連結区分・会計基準の公表比率を取得する。
  # IFRS移行年には日本基準のROEも併記されるため、基準間でフォールバックしない。
  class DisclosedRoeExtractor
    TAGS = {
      "japan_gaap" => "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults",
      "ifrs" => "jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults",
      "us_gaap" => "jpcrp_cor:RateOfReturnOnEquityUSGAAPSummaryOfBusinessResults"
    }.freeze

    # consolidation は Extractors::Base::CONSOLIDATED / NON_CONSOLIDATED
    def self.extract(xbrl, accounting_standard:, consolidation:)
      tag = TAGS[accounting_standard]
      return unless tag
      Expressions.ratio(tag).amount(xbrl, period: :duration, consolidation: Xbrl::ReportingPeriod::CONSOLIDATIONS[consolidation])
    end
  end
end
