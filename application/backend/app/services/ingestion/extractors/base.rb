module Ingestion
  module Extractors
    # 形式ごとのサブクラスの対応表（mapping）を StatementExtractor で評価する。
    # 形式のサブクラスは Ingestion::Mappings の対応表を使う。2つの表（INSTANT_MAPPING・DURATION_MAPPING）を定義したサブクラスは、
    # 表で決まる期間のまま評価する（TableMapping）
    class Base
      # ReportingPeriodへの検索キー。原本のID名ではなく、期間と連結区分を指定する。
      # 既存のマッピング・単体テストでも使えるようEDINETの標準名を共通キーにしている。
      CONSOLIDATED = "".freeze
      NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

      # 表の値の記法。単一タグは文字列、フォールバックは配列で書く（Ingestion::Expressions）
      def self.sum(*qnames, distinct_amounts: false, all_present: false) = Expressions.sum(*qnames, distinct_amounts:, all_present:)
      def self.max(*entries) = Expressions.max(*entries)
      def self.filer_ext(pattern) = Expressions.filer_ext(pattern)
      # 表の値を、evaluate(xbrl, 標準のコンテキストID) で金額を返す形にする
      def self.wrap(entry) = LegacyExpression.new(Expressions.wrap(entry))

      # この形式が生成し得る科目コードの一覧
      def self.item_codes = mapping.item_codes

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
