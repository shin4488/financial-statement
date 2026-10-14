module Ingestion
  module Expressions
    # 企業拡張タグのうち、要素名が正規表現に合うもの（filer_ext(/…SummaryOfBusinessResults\z/)）。要素名が会社ごとに違う科目を、
    # 名前を一覧にせず形で探す。合う要素の金額か精度が食い違うときは、どれが目的の科目か決められないため取らない。フォールバックの最後に置く
    FilerExtension = Data.define(:pattern) do
      def amount(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        (qname = match(source, context)) && source.money(qname, context)
      end

      def evaluate(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        qname = match(source, context)
        Measured.new(source.money(qname, context), source.rounding_error(qname, context)) if qname
      end

      def blank?(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        texts = source.element_names("filer_ext").grep(pattern).filter_map { |name| source.text("filer_ext:#{name}", context) }
        texts.any? && texts.all?(&:empty?)
      end

      private
        def match(source, context)
          qnames = source.element_names("filer_ext").grep(pattern).map { |name| "filer_ext:#{name}" }
                         .reject { |qname| source.money(qname, context).nil? }
          qnames.first if qnames.map { |qname| [ source.money(qname, context), source.rounding_error(qname, context) ] }.uniq.one?
        end
    end
  end
end
