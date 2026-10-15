module Ingestion
  module Mappings
    # 形式の対応表。共有する部品と、その形式に固有の部品（define のブロック）を組み合わせて作る（継承でなく合成）。
    # 科目の期間は科目カタログ（FinancialStatements::ItemCatalog）から決める。期首の科目は対応表に書かず、
    # カタログの opening_of の科目がこの対応表にあれば、その取得式で前期末（:prior_instant）を引く
    class Mapping
      Item = Data.define(:code, :period, :expression)

      # items は評価する科目（カタログの順）。Ingestion::StatementExtractor が評価する
      attr_reader :format, :sections, :items

      def self.define(format, *sections, &) = new(format, Section.define(&), *sections)

      def initialize(format, *sections)
        entries = sections.flat_map(&:entries)
        validate(format, entries.map(&:code))
        @format = format
        @sections = sections.freeze
        @expressions = entries.to_h { |entry| [ entry.code, entry.expression ] }.freeze
        @replacements = entries.to_h { |entry| [ entry.code, entry.replacements ] }.freeze
        @items = FinancialStatements::ItemCatalog::ITEMS.filter_map do |item|
          if item.opening?
            (expression = @expressions[item.opening_of]) && Item.new(item.code, :prior_instant, expression)
          elsif (expression = @expressions[item.code])
            Item.new(item.code, item.period, expression)
          end
        end.freeze
      end

      def expression(code) = @expressions[code]

      # 差し替えのときだけ使う候補。なければ空
      def replacements(code) = @replacements.fetch(code, [])

      # この形式が作る科目コード（期首の科目を含む）。BSやCFの式の行を作る形式かの判定に使う
      def item_codes = items.map(&:code)

      private
        # 同じ科目を2つの部品に書くと、後の部品が黙って上書きするため、読込時に止める
        def validate(format, codes)
          duplicated = codes.tally.filter_map { |code, count| code if count > 1 }
          raise ArgumentError, "#{format}: #{duplicated.join(", ")} defined in more than one section" if duplicated.any?
          unknown = codes - FinancialStatements::ItemCatalog::ALL
          raise ArgumentError, "#{format}: #{unknown.join(", ")} not in the item catalog" if unknown.any?
          openings = codes & FinancialStatements::ItemCatalog.opening_codes
          raise ArgumentError, "#{format}: #{openings.join(", ")} are opening items derived from the catalog" if openings.any?
        end
    end
  end
end
