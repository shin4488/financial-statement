module Ingestion
  module Extractors
    # 形式ごとのサブクラスが定義する2つの表（INSTANT_MAPPING・DURATION_MAPPING）を対応表にし、StatementExtractor で評価する
    class Base
      # ReportingPeriodへの検索キー。原本のID名ではなく、期間と連結区分を指定する。
      # 既存のマッピング・単体テストでも使えるようEDINETの標準名を共通キーにしている。
      CONSOLIDATED = "".freeze
      NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

      # 同じ有報・同じ連結区分の前期末を期首として使う。別の有報を検索して補完しない。
      OPENING_ITEMS = {
        "cf.cash_end" => "cf.cash_begin",
        "bs.assets" => "bs.assets_begin",
        "bs.equity_attributable_to_owners" => "bs.equity_attributable_to_owners_begin"
      }.freeze

      # 表の値の記法。単一タグは文字列、フォールバックは配列で書く（Ingestion::Expressions）
      def self.sum(*qnames, distinct_amounts: false, all_present: false) = Expressions.sum(*qnames, distinct_amounts:, all_present:)
      def self.max(*entries) = Expressions.max(*entries)
      def self.filer_ext(pattern) = Expressions.filer_ext(pattern)
      # 表の値を、evaluate(xbrl, 標準のコンテキストID) で金額を返す形にする（形式判定が経常収益のタグを読む）
      def self.wrap(entry) = LegacyExpression.new(Expressions.wrap(entry))

      # この形式が生成し得る科目コードの一覧
      def self.item_codes
        codes = self::INSTANT_MAPPING.keys + self::DURATION_MAPPING.keys
        OPENING_ITEMS.each { |closing, opening| codes << opening if self::INSTANT_MAPPING.key?(closing) }
        codes
      end

      def self.mapping = (@mapping ||= TableMapping.new(self::INSTANT_MAPPING, self::DURATION_MAPPING))

      def initialize(xbrl, consolidation)
        @xbrl = xbrl
        @c = consolidation # コンテキストサフィックス
      end

      # {item_code => amount} を返す。取れなかった科目はキーごと入れない
      def extract
        StatementExtractor.amounts(self.class.mapping, source: @xbrl, consolidation: Xbrl::ReportingPeriod::CONSOLIDATIONS[@c])
      end
    end
  end
end
