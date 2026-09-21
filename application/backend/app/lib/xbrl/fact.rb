module Xbrl
  # 値・開示精度・単位を一体で保持する。異なる候補の値と精度を組み合わせない。
  class Fact < Data.define(:value, :decimals, :unit)
    BIGINT_RANGE = (-2**63..2**63 - 1)
    CURRENCY_PREFIX = "{http://www.xbrl.org/2003/iso4217}".freeze
    JPY = "#{CURRENCY_PREFIX}JPY".freeze

    def money
      return if unit&.start_with?(CURRENCY_PREFIX) && unit != JPY
      return if value.nil? || value.empty?
      number = Integer(value, exception: false)
      BIGINT_RANGE.cover?(number) ? number : nil
    end

    # 切捨て開示も含むため1表示単位未満を上限とする。
    def rounding_error
      return 0.to_d if decimals == "INF"
      places = Integer(decimals, exception: false)
      return nil unless places && (-18..18).cover?(places)
      BigDecimal("10") ** -places
    end
  end
end
