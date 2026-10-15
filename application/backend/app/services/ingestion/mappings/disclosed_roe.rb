module Ingestion
  module Mappings
    # 公表ROE（financial_statements.disclosed_roe に保存する比率）。タグを形式でなく区分の会計基準で選ぶため、形式の対応表に含めず、
    # 対応する形式がない区分（unsupported）でも取る。IFRS移行年には日本基準のROEも併記されるため、基準間でフォールバックしない。
    # 科目カタログにない値のため、期間（当期）をここに書く
    module DisclosedRoe
      PERIOD = :duration
      EXPRESSIONS = {
        "japan_gaap" => Expressions.ratio("jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults"),
        "ifrs" => Expressions.ratio("jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults"),
        "us_gaap" => Expressions.ratio("jpcrp_cor:RateOfReturnOnEquityUSGAAPSummaryOfBusinessResults")
      }.freeze

      # 会計基準に対応するタグがなければ nil
      def self.amount(source, accounting_standard:, consolidation:)
        EXPRESSIONS[accounting_standard]&.amount(source, period: PERIOD, consolidation: consolidation)
      end
    end
  end
end
