module Ingestion
  module Mappings
    # 対応表の部品。科目コードごとに取得式（Ingestion::Expressions の記法）を持つ。期間は書かない（科目カタログから決まる）
    class Section
      # replacements は差し替えのときだけ使う候補。通常の取得では評価せず、補正ルールが通常の候補の後に試す
      Entry = Data.define(:code, :expression, :replacements)

      attr_reader :entries

      # ブロックの中で item "科目コード", 取得の記法, replacements: [候補, …] と書く。sum・max・filer_ext も呼べる
      def self.define(&) = new(Definition.new.tap { |definition| definition.instance_exec(&) }.entries)

      def initialize(entries)
        duplicated = entries.map(&:code).tally.filter_map { |code, count| code if count > 1 }
        raise ArgumentError, "the section defines #{duplicated.join(", ")} more than once" if duplicated.any?
        @entries = entries.freeze
      end

      class Definition
        attr_reader :entries

        def initialize
          @entries = []
        end

        def item(code, spec, replacements: [])
          @entries << Entry.new(code, Expressions.wrap(spec), replacements.map { |entry| Expressions.wrap(entry) }.freeze)
        end

        def sum(*qnames, distinct_amounts: false, all_present: false) = Expressions.sum(*qnames, distinct_amounts:, all_present:)
        def max(*entries) = Expressions.max(*entries)
        def filer_ext(pattern) = Expressions.filer_ext(pattern)
      end
      private_constant :Definition
    end
  end
end
