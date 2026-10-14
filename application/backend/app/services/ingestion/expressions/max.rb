module Ingestion
  module Expressions
    # 最大値（max("…:A", sum("…:B", "…:C"))）。同じ科目の総額の候補が複数併記され、どれが総額かが企業のタグ付けで揺れる場合
    # （売上高と営業収益）に、内訳は総額を超えないことを根拠に「最も包括的な値」を採る。要素にはタグか sum を置ける
    Max = Data.define(:entries) do
      def amount(source, period:, consolidation:)
        amounts = entries.filter_map { |entry| entry.amount(source, period:, consolidation:) }
        amounts.max if amounts.any?
      end

      # 同じ金額の候補が複数あれば、先頭の候補の端数を使う
      def evaluate(source, period:, consolidation:)
        measured = entries.filter_map { |entry| entry.evaluate(source, period:, consolidation:) }
        return if measured.empty?
        amount = measured.map(&:amount).max
        Measured.new(amount, measured.find { |candidate| candidate.amount == amount }&.rounding_error)
      end

      def blank?(source, period:, consolidation:)
        amount(source, period:, consolidation:).nil? && entries.any? { |entry| entry.blank?(source, period:, consolidation:) }
      end
    end
  end
end
