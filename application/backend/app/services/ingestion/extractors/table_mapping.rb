module Ingestion
  module Extractors
    # Extractorの2つの表（当期末の INSTANT_MAPPING・当期の DURATION_MAPPING）から作る、StatementExtractor の対応表。
    # 期間は表で決まる（XBRLは科目の期間の種類ごとにコンテキストIDが違う。BSの残高は時点、PL・CFの増減は期間）。
    # 当期末の表に期末の科目があれば、同じ取得式で前期末を引いて期首の科目にする
    class TableMapping
      Item = Data.define(:code, :period, :expression)

      attr_reader :items

      def initialize(instant, duration)
        instant = instant.transform_values { |spec| Expressions.wrap(spec) }
        duration = duration.transform_values { |spec| Expressions.wrap(spec) }
        openings = Base::OPENING_ITEMS.filter_map do |closing, opening|
          (expression = instant[closing]) && Item.new(opening, :prior_instant, expression)
        end
        @items = (instant.map { |code, expression| Item.new(code, :instant, expression) } +
                  duration.map { |code, expression| Item.new(code, :duration, expression) } + openings).freeze
        @expressions = instant.merge(duration).freeze
      end

      def expression(code) = @expressions[code]
    end
  end
end
