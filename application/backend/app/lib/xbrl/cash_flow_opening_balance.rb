module Xbrl
  # 期首 + 当期増減 + 連結範囲変更等 = 期末を、同一通貨・開示精度で照合する。
  # 計算値で原本を置き換えず、式を満たす原本の期首額だけを返す。
  class CashFlowOpeningBalance
    def self.reconcile(opening:, closing:, change:, adjustments:)
      facts = [ opening, closing, change, *adjustments ]
      return if facts.any?(&:nil?)
      return unless facts.map(&:unit).uniq == [ Fact::JPY ]
      return if facts.any? { |value| value.money.nil? || value.rounding_error.nil? }
      return if opening.money.negative? || closing.money.negative?

      difference = closing.money - opening.money - change.money - adjustments.sum(&:money)
      tolerance = facts.sum(&:rounding_error)
      opening if difference.zero? || difference.abs < tolerance
    end
  end
end
