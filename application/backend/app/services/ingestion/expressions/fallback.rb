module Ingestion
  module Expressions
    # フォールバック（[ "…:A", "…:B" ]）。先頭から順に評価し、先に取れた候補を採る
    Fallback = Data.define(:entries) do
      def amount(source, period:, consolidation:) = entries.lazy.filter_map { |entry| entry.amount(source, period:, consolidation:) }.first

      def evaluate(source, period:, consolidation:) = entries.lazy.filter_map { |entry| entry.evaluate(source, period:, consolidation:) }.first

      def blank?(source, period:, consolidation:)
        amount(source, period:, consolidation:).nil? && entries.any? { |entry| entry.blank?(source, period:, consolidation:) }
      end
    end
  end
end
