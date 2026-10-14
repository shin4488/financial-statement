module Ingestion
  module Expressions
    # 合算（sum("…:A", "…:B")）。合計タグを持たず事業区分ごとに分けて開示する業種（鉄道・海運・電気通信の営業収益など）のために、
    # 存在するタグだけを足した値を1つの科目にする。1つも無ければ nil（「開示なし」に0を保存しない）。
    # 部分集合でも合算するのは、事業区分の開示の有無が企業ごとに違うため（鉄道事業のみの会社と、鉄道と不動産の会社を同じ表で引く）。
    #   distinct_amounts: true … 同じ金額のタグは1回だけ数える。内訳として足すタグに、会社によっては同じ総額を重ねて付けることがある
    #   all_present: true      … すべてのタグに値があるときだけ足し、1つでもなければ nil。合計の行がなく内訳の行だけを並べる会社のための候補で、
    #                            片方の行だけを合計として使わないため
    Sum = Data.define(:tags, :distinct_amounts, :all_present) do
      def initialize(tags:, distinct_amounts: false, all_present: false) = super

      def amount(source, period:, consolidation:)
        amounts = counted_tags(source, period, consolidation).map { |tag| tag.amount(source, period:, consolidation:) }
        amounts.sum if amounts.any?
      end

      # 端数の上限は足したタグの端数の和。精度が不明なタグが混ざれば不明（nil）のままにする
      def evaluate(source, period:, consolidation:)
        measured = counted_tags(source, period, consolidation).map { |tag| tag.evaluate(source, period:, consolidation:) }
        return if measured.empty?
        errors = measured.map(&:rounding_error)
        Measured.new(measured.sum(&:amount), (errors.sum if errors.none?(&:nil?)))
      end

      def blank?(source, period:, consolidation:)
        amount(source, period:, consolidation:).nil? && tags.any? { |tag| tag.blank?(source, period:, consolidation:) }
      end

      private
        def counted_tags(source, period, consolidation)
          present = tags.reject { |tag| tag.amount(source, period:, consolidation:).nil? }
          return [] if all_present && present.size < tags.size
          distinct_amounts ? present.uniq { |tag| tag.amount(source, period:, consolidation:) } : present
        end
    end
  end
end
