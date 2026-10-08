module Ingestion
  module Extractors
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

      # マッピング表の値の書き方:
      #   "jppfs_cor:NetSales"                  … 単一タグ
      #   [ "…:A", "…:B" ]                     … フォールバック順のリスト（先に取れた方を採用）
      #   sum("…:A", "…:B")                     … 合算。合計タグを持たず事業区分ごとに分けて開示する業種
      #                                           （鉄道・海運・電気通信の営業収益など）のために、
      #                                           存在するタグだけを足した値を1つの科目にする。
      #                                           リストの要素にも置ける（例: [ "…:Total", sum("…:A", "…:B") ]）
      #   sum("…:A", "…:B", distinct_amounts: true)
      #                                       … 合算。ただし同じ金額のタグは1回だけ数える。内訳として足すタグに、
      #                                           会社によっては同じ総額を重ねて付けることがある場合に使う
      #   max("…:A", sum("…:B", "…:C"))        … 最大値。同じ科目の総額候補が複数併記され、どれが総額かが
      #                                           企業のタグ付けで揺れる場合（売上高と営業収益）に、内訳は総額を
      #                                           超えないことを根拠に「最も包括的な値」を採る。要素にはタグかsumを置ける
      #   "filer_ext:BusinessRevenues"          … 企業拡張タグのうち、原本で意味を確かめた要素名。フォールバックの最後に置く
      #   filer_ext(/…SummaryOfBusinessResults\z/)
      #                                       … 企業拡張タグのうち、要素名が正規表現に合うもの。要素名が会社ごとに違う科目を、
      #                                           名前を一覧にせず形で探す。合う要素の金額か精度が食い違うときは、
      #                                           どれが目的の科目か決められないため取らない。フォールバックの最後に置く
      #
      # 各記法は「XBRLとコンテキストを受けて金額かnilを返す」evaluateを持つ値オブジェクト。
      # 記法を増やすときはStructを1つ足せばよく、評価側（lookup）や各Extractorには手が入らない。
      # blank?は、金額が取れず、行はあるが値が空（表では「－」。XBRLでは値のないタグ）のときにtrueを返す

      Tag = Struct.new(:qname) do
        def evaluate(xbrl, context) = xbrl.money(qname, context)
        def rounding_error(xbrl, context) = xbrl.rounding_error(qname, context)
        def blank?(xbrl, context) = xbrl.text(qname, context) == ""
      end

      Sum = Struct.new(:tags, :distinct_amounts) do
        def rounding_error(xbrl, context)
          errors = counted_tags(xbrl, context).map { |tag| tag.rounding_error(xbrl, context) }
          errors.sum if errors.any? && errors.none?(&:nil?)
        end

        # 存在するタグだけを合算し、1つも無ければnil（「開示なし」に0を保存しない）。
        # 部分集合でも合算するのは、事業区分の開示有無が企業ごとに違うため
        # （例: 鉄道事業のみの会社と、鉄道+不動産の会社が同じ表で引ける）
        def evaluate(xbrl, context)
          values = counted_tags(xbrl, context).map { |tag| tag.evaluate(xbrl, context) }
          values.sum if values.any?
        end

        def blank?(xbrl, context) = evaluate(xbrl, context).nil? && tags.any? { |tag| tag.blank?(xbrl, context) }

        private
          def counted_tags(xbrl, context)
            present = tags.reject { |tag| tag.evaluate(xbrl, context).nil? }
            distinct_amounts ? present.uniq { |tag| tag.evaluate(xbrl, context) } : present
          end
      end

      Max = Struct.new(:entries) do
        def rounding_error(xbrl, context)
          value = evaluate(xbrl, context)
          entries.find { |entry| !value.nil? && entry.evaluate(xbrl, context) == value }&.rounding_error(xbrl, context)
        end

        def evaluate(xbrl, context)
          values = entries.filter_map { |entry| entry.evaluate(xbrl, context) }
          values.max if values.any?
        end

        def blank?(xbrl, context) = evaluate(xbrl, context).nil? && entries.any? { |entry| entry.blank?(xbrl, context) }
      end

      FilerExtension = Struct.new(:pattern) do
        def evaluate(xbrl, context) = (qname = match(xbrl, context)) && xbrl.money(qname, context)
        def rounding_error(xbrl, context) = (qname = match(xbrl, context)) && xbrl.rounding_error(qname, context)

        def blank?(xbrl, context)
          texts = xbrl.element_names("filer_ext").grep(pattern).filter_map { |name| xbrl.text("filer_ext:#{name}", context) }
          texts.any? && texts.all?(&:empty?)
        end

        private
          def match(xbrl, context)
            qnames = xbrl.element_names("filer_ext").grep(pattern).map { |name| "filer_ext:#{name}" }
                         .reject { |qname| xbrl.money(qname, context).nil? }
            qnames.first if qnames.map { |qname| [ xbrl.money(qname, context), xbrl.rounding_error(qname, context) ] }.uniq.one?
          end
      end

      def self.sum(*qnames, distinct_amounts: false) = Sum.new(qnames.map { |qname| Tag.new(qname) }, distinct_amounts)
      def self.max(*entries) = Max.new(entries.map { |entry| wrap(entry) })
      def self.filer_ext(pattern) = FilerExtension.new(pattern)
      # マッピング表では単一タグを裸の文字列で書けるようにしているため、評価前にTagへ揃える
      def self.wrap(entry) = entry.is_a?(String) ? Tag.new(entry) : entry

      # この形式が生成し得る科目コードの一覧
      def self.item_codes
        codes = self::INSTANT_MAPPING.keys + self::DURATION_MAPPING.keys
        OPENING_ITEMS.each { |closing, opening| codes << opening if self::INSTANT_MAPPING.key?(closing) }
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
        OPENING_ITEMS.each do |closing, opening|
          if (spec = self.class::INSTANT_MAPPING[closing])
            put(result, opening, lookup(spec, "Prior1YearInstant#{@c}"))
          end
        end
        if !result.key?("cf.cash_begin") && result.key?("cf.cash_end") && @xbrl.respond_to?(:reconciled_opening_cash)
          if (fact = @xbrl.reconciled_opening_cash(consolidation: @c, closing_amount: result["cf.cash_end"]))
            result["cf.cash_begin"] = fact.money
            result.rounding_errors["cf.cash_begin"] = fact.rounding_error
          end
        end
        use_cash_flow_statement_balances(result)
        replace_unverified_revenue(result)
        verify_zero_revenue(result)
        result
      end

      private
        # CFの期首残・期末残は、期末残の取得候補の先頭のタグで取る（IFRSは財政状態計算書と同じ現金及び現金同等物のタグ）。
        # CF計算書の残高がその額と違う会社は、CF計算書の残高を2番目以降の標準タグで開示する。ただし、そのタグを調整後の期首残高など
        # ほかの行に付ける会社もあるため、期首残・期末残をそのタグの額にしたときにCFの式が端数の範囲で成り立つ場合だけ差し替える。
        # 経営指標の要約のタグは本表の残高ではないため候補にしない
        def use_cash_flow_statement_balances(result)
          spec = self.class::INSTANT_MAPPING["cf.cash_end"]
          return unless spec && result.key?("cf.cash_end")
          balances = { "cf.cash_end" => "CurrentYearInstant#{@c}", "cf.cash_begin" => "Prior1YearInstant#{@c}" }
          statement_entries(spec).drop(1).each do |entry|
            candidate = self.class.wrap(entry)
            trial = FinancialStatements::Amounts.new.merge!(result)
            trial.rounding_errors.merge!(result.rounding_errors)
            balances.each do |code, context|
              value = candidate.evaluate(@xbrl, context)
              next if value.nil?
              trial[code] = value
              trial.rounding_errors[code] = candidate.rounding_error(@xbrl, context)
            end
            next if trial == result || FinancialStatements::CashFlowVerification.mismatch(trial)
            result.merge!(trial.slice(*balances.keys))
            result.rounding_errors.merge!(trial.rounding_errors.slice(*balances.keys))
            return
          end
        end

        # 売上のタグに、合計ではなく内訳だけが付いた書類がある（標準タグの売上高が製品売上高だけで、
        # 合計の事業収益は企業拡張タグに付けるなど）。売上が経営指標の要約の売上と合わないときは、
        # 売上の取得候補のうち要約と一致するものを売上にする。どれも合わなければ、取込の照合で警告する。
        # 要約のタグ（jpcrp_cor）は照合の相手なので候補にしない。要約の値そのものを売上にすると、照合の意味がなくなるため
        def replace_unverified_revenue(result)
          spec = self.class::DURATION_MAPPING["pl.revenue"]
          return unless spec && FinancialStatements::RevenueVerification.status(result) == :mismatched
          context = "CurrentYearDuration#{@c}"
          statement_entries(spec).each do |entry|
            candidate = self.class.wrap(entry)
            value = candidate.evaluate(@xbrl, context)
            next if value.nil?
            error = candidate.rounding_error(@xbrl, context)
            next unless FinancialStatements::RevenueVerification.verified?(result, value, error)
            result["pl.revenue"] = value
            result.rounding_errors["pl.revenue"] = error
            return
          end
        end

        # 売上がない会社（創薬ベンチャーなど）は、経営指標の要約の売上を「－」で開示し、損益計算書では売上の行を「－」にするか、
        # 前期も売上がなければ行そのものを載せない。本表の売上の取得候補のどれからも売上が取れず、要約の売上が「－」のときに、
        # 売上0と確かめられたとして両方に0を保存する。要約に売上の行がないときは、売上が一覧にない要素名で開示されている
        # おそれがあり、0にすると実際の売上と違う値になるため保存しない。
        # 経営指標の要約だけで作る形式は、本表で売上がないことを確かめられないため対象にしない。
        # 連結初年度で連結の損益計算書を作っていない書類も、売上を含むすべての行が「－」になるため、
        # 損益の値がある（損益計算書を作っている）ときだけ確かめる
        def verify_zero_revenue(result)
          revenue_spec, summary_spec = self.class::DURATION_MAPPING.values_at("pl.revenue", "pl.summary_revenue")
          return unless revenue_spec && summary_spec && statement_entries(revenue_spec).any?
          return if result.key?("pl.revenue") || result.key?("pl.summary_revenue")
          return unless %w[pl.operating_profit pl.profit_before_tax pl.profit].any? { |code| result.key?(code) }
          context = "CurrentYearDuration#{@c}"
          return unless entries(summary_spec).any? { |entry| self.class.wrap(entry).blank?(@xbrl, context) }
          %w[pl.revenue pl.summary_revenue].each do |code|
            result[code] = 0
            result.rounding_errors[code] = 0.to_d
          end
        end

        # 取得候補のうち、財務諸表の本表のもの（経営指標の要約のタグ jpcrp_cor を除く）
        def statement_entries(spec) = entries(spec).reject { |entry| entry.is_a?(String) && entry.start_with?("jpcrp_cor:") }

        def put(result, code, value)
          unless value.nil?
            result[code] = value
            result.rounding_errors[code] = @last_rounding_error
          end
        end

        # マッピング表の1エントリ（上記の記法のいずれか）を評価する
        def lookup(spec, context)
          entries(spec).each do |entry|
            wrapped = self.class.wrap(entry)
            value = wrapped.evaluate(@xbrl, context)
            next if value.nil?
            @last_rounding_error = wrapped.rounding_error(@xbrl, context)
            return value
          end
          nil
        end

        # 単一の記法も「要素1つのフォールバックリスト」に揃えて同じ経路で扱う
        # （Array()を使わないのはStructがto_aで展開されてしまうため）
        def entries(spec) = spec.is_a?(Array) ? spec : [ spec ]
    end
  end
end
