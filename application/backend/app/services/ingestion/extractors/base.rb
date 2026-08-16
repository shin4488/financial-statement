module Ingestion
  module Extractors
    class Base
      # XBRLコンテキストIDのサフィックス。連結はサフィックスなし、単体は_NonConsolidatedMember
      # （例: CurrentYearInstant / CurrentYearInstant_NonConsolidatedMember。全形式共通の規則）
      CONSOLIDATED = "".freeze
      NON_CONSOLIDATED = "_NonConsolidatedMember".freeze

      # マッピング表の値の書き方（4記法）:
      #   "jppfs_cor:NetSales"                  … 単一タグ
      #   [ "…:A", "…:B" ]                     … フォールバック順のリスト（先に取れた方を採用）
      #   sum("…:A", "…:B")                     … 合算。合計タグを持たず事業区分ごとに分けて開示する業種
      #                                           （鉄道・海運・電気通信の営業収益など）のために、
      #                                           存在するタグだけを足した値を1つの科目にする。
      #                                           リストの要素にも置ける（例: [ "…:Total", sum("…:A", "…:B") ]）
      #   max("…:A", sum("…:B", "…:C"))        … 最大値。同じ科目の総額候補が複数併記され、どれが総額かが
      #                                           企業のタグ付けで揺れる場合（売上高と営業収益）に、内訳は総額を
      #                                           超えないことを根拠に「最も包括的な値」を採る。要素にはタグかsumを置ける
      Sum = Struct.new(:qnames)
      Max = Struct.new(:entries)
      def self.sum(*qnames) = Sum.new(qnames)
      def self.max(*entries) = Max.new(entries)

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
        self.class::INSTANT_MAPPING.each do |code, spec|
          put(result, code, lookup(spec, "CurrentYearInstant#{@c}"))
        end
        self.class::DURATION_MAPPING.each do |code, spec|
          put(result, code, lookup(spec, "CurrentYearDuration#{@c}"))
        end
        extract_extras(result)
        result
      end

      private
        # 単純な「1コード→タグの対応」で表せない科目のためのフック。
        # 具体例: 期首残高（Prior1YearInstantという別コンテキストを参照）。各形式クラスが必要な分だけ実装する
        def extract_extras(result); end

        def put(result, code, value)
          result[code] = value unless value.nil?
        end

        # マッピング表の1エントリ（上記4記法のいずれか）を評価する。
        # 単一タグ・合算・最大値を「要素1つのフォールバックリスト」に揃えて同じ経路で扱う
        # （Array()を使わないのはStructがto_aで展開されてしまうため）
        def lookup(spec, context)
          entries = spec.is_a?(Array) ? spec : [ spec ]
          entries.lazy.filter_map { |entry| evaluate(entry, context) }.first
        end

        # 存在するタグだけを合算・比較し、1つも無ければnil（「開示なし」に0を保存しない）。
        # 部分集合でも合算するのは、事業区分の開示有無が企業ごとに違うため
        # （例: 鉄道事業のみの会社と、鉄道+不動産の会社が同じ表で引ける）
        def evaluate(entry, context)
          case entry
          when Sum
            values = entry.qnames.filter_map { |q| @xbrl.money(q, context) }
            values.sum if values.any?
          when Max
            values = entry.entries.filter_map { |e| evaluate(e, context) }
            values.max if values.any?
          else
            @xbrl.money(entry, context)
          end
        end
    end
  end
end
