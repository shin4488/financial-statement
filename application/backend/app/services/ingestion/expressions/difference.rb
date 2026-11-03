module Ingestion
  module Expressions
    # 差（difference("…:A", "…:B")）。合計と内訳の1つにだけタグがあり、残りの内訳の小計にタグがない会社のために、合計から内訳を引いた残りを1つの科目にする
    # （営業収益と売上高にタグがあり、営業収入は賃貸収入などの内訳の行だけの会社）。
    # 両方に値があり、差が正のときだけ取る。差が0以下なら、2つのタグは合計と内訳の関係にない（同じ総額を両方に付けるなど）ため取らない
    Difference = Data.define(:total, :part) do
      def amount(source, period:, consolidation:)
        total_amount = total.amount(source, period:, consolidation:)
        part_amount = part.amount(source, period:, consolidation:)
        return if total_amount.nil? || part_amount.nil?
        total_amount - part_amount if total_amount > part_amount
      end

      # 端数の上限は2つのタグの端数の和。精度が不明なタグがあれば不明（nil）のままにする
      def evaluate(source, period:, consolidation:)
        measured = [ total, part ].map { |tag| tag.evaluate(source, period:, consolidation:) }
        return if measured.any?(&:nil?)
        total_measured, part_measured = measured
        return unless total_measured.amount > part_measured.amount
        errors = measured.map(&:rounding_error)
        Measured.new(total_measured.amount - part_measured.amount, (errors.sum if errors.none?(&:nil?)))
      end

      def blank?(source, period:, consolidation:)
        amount(source, period:, consolidation:).nil? && [ total, part ].any? { |tag| tag.blank?(source, period:, consolidation:) }
      end
    end
  end
end
