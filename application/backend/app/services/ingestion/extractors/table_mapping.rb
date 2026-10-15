module Ingestion
  module Extractors
    # Extractorの2つの表（当期末の INSTANT_MAPPING・当期の DURATION_MAPPING）から作る、StatementExtractor の対応表。
    # 期間は表で決まる（XBRLは科目の期間の種類ごとにコンテキストIDが違う。BSの残高は時点、PL・CFの増減は期間）。
    # 当期末の表に、科目カタログの期首の科目の opening_of があれば、同じ取得式で前期末を引いて期首の科目にする
    class TableMapping
      Item = Data.define(:code, :period, :expression)

      attr_reader :items

      def initialize(instant, duration)
        instant = instant.transform_values { |spec| Expressions.wrap(spec) }
        duration = duration.transform_values { |spec| Expressions.wrap(spec) }
        openings = FinancialStatements::ItemCatalog::ITEMS.select(&:opening?).filter_map do |item|
          (expression = instant[item.opening_of]) && Item.new(item.code, :prior_instant, expression)
        end
        @items = (instant.map { |code, expression| Item.new(code, :instant, expression) } +
                  duration.map { |code, expression| Item.new(code, :duration, expression) } + openings).freeze
        @expressions = instant.merge(duration).freeze
      end

      def expression(code) = @expressions[code]

      # 差し替えのときだけ使う候補は、2つの表には書けない
      def replacements(_code) = []

      def item_codes = items.map(&:code)
    end
  end
end
