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
      #   consistent("…:A", sum("…:B", "…:C")) … 総額候補が複数あれば開示精度内の一致を要求する。
      #                                           金額の大小から総額・内訳を推測しない。
      #
      # 各記法は「XBRLとコンテキストを受けて金額かnilを返す」evaluateを持つ値オブジェクト。
      # 記法を増やすときはStructを1つ足せばよく、評価側（lookup）や各Extractorには手が入らない

      Tag = Struct.new(:qname) do
        def evaluate(xbrl, context) = xbrl.money(qname, context)
        def rounding_error(xbrl, context) = xbrl.rounding_error(qname, context)
      end

      Sum = Struct.new(:tags) do
        def rounding_error(xbrl, context)
          errors = tags.select { |tag| !tag.evaluate(xbrl, context).nil? }
                       .map { |tag| tag.rounding_error(xbrl, context) }
          errors.sum if errors.any? && errors.none?(&:nil?)
        end

        # 存在するタグだけを合算し、1つも無ければnil（「開示なし」に0を保存しない）。
        # 部分集合でも合算するのは、事業区分の開示有無が企業ごとに違うため
        # （例: 鉄道事業のみの会社と、鉄道+不動産の会社が同じ表で引ける）
        def evaluate(xbrl, context)
          values = tags.filter_map { |tag| tag.evaluate(xbrl, context) }
          values.sum if values.any?
        end
      end

      Consistent = Struct.new(:entries, :components) do
        def candidates(xbrl, context)
          entries.select { |entry| !entry.evaluate(xbrl, context).nil? }
        end

        def evaluate(xbrl, context)
          available = candidates(xbrl, context)
          return nil if available.empty?
          values = components.map { |entry| entry.evaluate(xbrl, context) }
          if values.any? && values.none?(&:nil?)
            component_errors = components.map { |entry| entry.rounding_error(xbrl, context) }
            available = available.select do |entry|
              difference = (entry.evaluate(xbrl, context) - values.sum).abs
              errors = component_errors + [ entry.rounding_error(xbrl, context) ]
              difference.zero? || (errors.none?(&:nil?) && difference < errors.sum)
            end
            return nil if available.empty?
          end
          first = available.first
          value = first.evaluate(xbrl, context)
          compatible = available.drop(1).all? do |entry|
            difference = (entry.evaluate(xbrl, context) - value).abs
            errors = [ first.rounding_error(xbrl, context), entry.rounding_error(xbrl, context) ]
            difference.zero? || (errors.none?(&:nil?) && difference < errors.sum)
          end
          value if compatible
        end

        def rounding_error(xbrl, context)
          candidates(xbrl, context).find { |entry| entry.evaluate(xbrl, context) == evaluate(xbrl, context) }&.rounding_error(xbrl, context)
        end
      end

      def self.sum(*qnames) = Sum.new(qnames.map { |qname| Tag.new(qname) })
      def self.consistent(*entries, components: []) = Consistent.new(entries.map { |entry| wrap(entry) }, components.map { |entry| wrap(entry) })
      # マッピング表では単一タグを裸の文字列で書けるようにしているため、評価前にTagへ揃える
      def self.wrap(entry) = entry.is_a?(String) ? Tag.new(entry) : entry

      # この形式が生成し得る科目コードの一覧
      def self.item_codes
        codes = self::INSTANT_MAPPING.keys + self::DURATION_MAPPING.keys
        codes << "cf.cash_begin" if self::INSTANT_MAPPING.key?("cf.cash_end")
        codes
      end

      def initialize(xbrl, consolidation)
        @xbrl = xbrl
        @c = consolidation # コンテキストサフィックス
      end

      # {item_code => amount} を返す。取れなかった科目はキーごと入れない
      # （「開示なし」をnilや0でなくキーの不存在で表す。DBの「行の不存在=開示なし」と対になる規約）
      def extract
        result = FinancialStatements::Amounts.new
        # マッピングを2表に分ける理由: XBRLは科目の期間タイプごとにコンテキストIDが違う。
        # BS残高系=Instant（時点） / PL・CF増減系=Duration（期間）
        self.class::INSTANT_MAPPING.each do |code, spec|
          put(result, code, lookup(spec, "CurrentYearInstant#{@c}"))
        end
        self.class::DURATION_MAPPING.each do |code, spec|
          put(result, code, lookup(spec, "CurrentYearDuration#{@c}"))
        end
        # CF期首残高 = 前期末時点の現金及び現金同等物。これは会計基準・業種によらない定義なので、
        # 期末残高（cf.cash_end）と同じタグを前期末（Prior1YearInstant）コンテキストで引いて導出する。
        # 各形式のマッピングには cf.cash_end だけ書けばよい
        if (cash_end_spec = self.class::INSTANT_MAPPING["cf.cash_end"])
          put(result, "cf.cash_begin", lookup(cash_end_spec, "Prior1YearInstant#{@c}"))
        end
        result
      end

      private
        def put(result, code, value)
          unless value.nil?
            result[code] = value
            result.rounding_errors[code] = @last_rounding_error
          end
        end

        # マッピング表の1エントリ（上記4記法のいずれか）を評価する。
        # 単一の記法も「要素1つのフォールバックリスト」に揃えて同じ経路で扱う
        # （Array()を使わないのはStructがto_aで展開されてしまうため）
        def lookup(spec, context)
          entries = spec.is_a?(Array) ? spec : [ spec ]
          entries.each do |entry|
            wrapped = self.class.wrap(entry)
            value = wrapped.evaluate(@xbrl, context)
            next if value.nil?
            @last_rounding_error = wrapped.rounding_error(@xbrl, context)
            return value
          end
          nil
        end
    end
  end
end
