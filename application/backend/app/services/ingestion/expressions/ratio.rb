module Ingestion
  module Expressions
    # 比率（ratio("…:RateOfReturnOnEquitySummaryOfBusinessResults")）。公表ROEのように、金額でない比率の値を文字列から読む。
    # 空・不正・非有限の値は0にせず、取らない
    Ratio = Data.define(:qname) do
      def amount(source, period:, consolidation:)
        value = BigDecimal(source.text(qname, Xbrl::ReportingPeriod.context_id(period, consolidation)).to_s, exception: false)
        value if value&.finite? && value.to_f.finite?
      end

      # 比率は開示精度から丸め誤差の上限を求めないため、端数は不明（nil）とする
      def evaluate(source, period:, consolidation:)
        value = amount(source, period:, consolidation:)
        Measured.new(value, nil) unless value.nil?
      end

      def blank?(source, period:, consolidation:) = source.text(qname, Xbrl::ReportingPeriod.context_id(period, consolidation)) == ""
    end
  end
end
