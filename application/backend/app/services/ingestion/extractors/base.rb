module Ingestion
  module Extractors
    class Base
      # XBRLコンテキストIDのサフィックス。連結はサフィックスなし、単体は_NonConsolidatedMember
      # （例: CurrentYearInstant / CurrentYearInstant_NonConsolidatedMember。全形式共通の規則）
      CONSOLIDATED = "".freeze
      NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

      def initialize(xbrl, consolidation)
        @xbrl = xbrl
        @c = consolidation # コンテキストサフィックス
      end

      # {item_code => amount} を返す。取れなかった科目はキーごと入れない
      # （「開示なし」をnilや0でなくキーの不存在で表す。DBの「行の不存在=開示なし」と対になる規約）
      def extract
        result = {}
        # マッピングを2表に分ける理由: XBRLは科目の期間タイプごとにコンテキストIDが違う。
        # BS残高系=Instant（時点） / PL・CF増減系=Duration（期間）
        self.class::INSTANT_MAPPING.each do |code, qnames|
          # Array(): マッピングの値は「単一タグの文字列」か「フォールバック順の配列」の両記法を許す
          v = @xbrl.money_first(Array(qnames), "CurrentYearInstant#{@c}")
          result[code] = v unless v.nil?
        end
        self.class::DURATION_MAPPING.each do |code, qnames|
          v = @xbrl.money_first(Array(qnames), "CurrentYearDuration#{@c}")
          result[code] = v unless v.nil?
        end
        extract_extras(result)
        result
      end

      private
        # 単純な「1コード→タグのフォールバックリスト」で表せない科目のためのフック。
        # 具体例: 期首残高（Prior1YearInstantという別コンテキストを参照）、
        #         のれん+無形の合算（2タグの加算）。各形式クラスが必要な分だけ実装する
        def extract_extras(result); end

        def put(result, code, value)
          result[code] = value unless value.nil?
        end
    end
  end
end
