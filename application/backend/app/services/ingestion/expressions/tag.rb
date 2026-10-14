module Ingestion
  module Expressions
    # 単一タグ（"jppfs_cor:NetSales"）。企業拡張タグも、原本で意味を確かめた要素名なら "filer_ext:BusinessRevenues" と書ける
    Tag = Data.define(:qname) do
      def amount(source, period:, consolidation:) = source.money(qname, Xbrl::ReportingPeriod.context_id(period, consolidation))

      def evaluate(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        amount = source.money(qname, context)
        Measured.new(amount, source.rounding_error(qname, context)) unless amount.nil?
      end

      def blank?(source, period:, consolidation:) = source.text(qname, Xbrl::ReportingPeriod.context_id(period, consolidation)) == ""

      # 経営指標の要約のタグか。要約は本表の値の照合の相手で、本表の値の差し替えの候補にしない
      def summary? = qname.start_with?("jpcrp_cor:")
    end
  end
end
