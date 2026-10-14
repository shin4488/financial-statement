module Xbrl
  # 当期末・当期・期首のfactを、期間と連結区分を指定して引く。既存Extractorが渡す標準のコンテキストIDも同じ指定として読む。
  # 元文書のIDへの別名付けではなく、全書類でcontextの内容を照合する読み取り専用ビュー。
  class ReportingPeriod
    CONSOLIDATIONS = { "" => :consolidated, "_NonConsolidatedMember" => :non_consolidated }.freeze
    # 期間の種類と、その期間を指すEDINETの標準のコンテキストID（連結区分の接尾辞を除く）
    PERIODS = { instant: "CurrentYearInstant", duration: "CurrentYearDuration", prior_instant: "Prior1YearInstant" }.freeze
    CONTEXT_IDS = PERIODS.to_a.product(CONSOLIDATIONS.to_a)
                         .to_h { |(period, name), (suffix, consolidation)| [ "#{name}#{suffix}", [ period, consolidation ] ] }.freeze
    STANDARD_IDS = CONTEXT_IDS.invert.freeze
    private_constant :CONTEXT_IDS, :STANDARD_IDS

    # 期間と連結区分を指す標準のコンテキストID。取得式は、標準のIDで答える文書（Xbrl::Document やspecの代役）にも同じ指定で問い合わせる
    def self.context_id(period, consolidation) = STANDARD_IDS.fetch([ period, consolidation ])

    # 標準のコンテキストIDが指す期間と連結区分の組（標準でないIDは nil）。旧い入口が受けるIDを組に読み替える
    def self.period_and_consolidation(context_id) = CONTEXT_IDS[context_id]

    def initialize(document, contexts:, start_date:, end_date:)
      @document = document
      @contexts = contexts
      @candidates = {}
      @facts = {}
      @beginnings = {}
      beginning = Context.date(start_date)
      ending = Context.date(end_date)
      entity = contexts["FilingDateInstant"]&.entity
      return unless beginning && ending && beginning <= ending && entity
      @entity = entity

      index = contexts.group_by { |_, context| [ context.entity, context.period, context.consolidation ] }
      CONSOLIDATIONS.each do |suffix, consolidation|
        start = statement_start(contexts["CurrentYearDuration#{suffix}"], entity, consolidation, ending) || beginning
        @beginnings[consolidation] = start
        dates = { instant: [ ending ], duration: [ start, ending ], prior_instant: [ start - 1 ] }
        dates.each do |period, value|
          @candidates[[ period, consolidation ]] = index.fetch([ entity, value, consolidation ], []).map(&:first)
        end
      end
    end

    def element_names(prefix) = @document.element_names(prefix)
    def money(qname, context) = fact_by_id(qname, context)&.money
    def text(qname, context) = fact_by_id(qname, context)&.value
    def rounding_error(qname, context) = fact_by_id(qname, context)&.rounding_error

    # period は :instant・:duration・:prior_instant、consolidation は :consolidated・:non_consolidated。
    # 値・開示精度・単位を組で返す
    def fact(qname, period:, consolidation:)
      @facts.fetch([ qname, period, consolidation ]) do |key|
        facts = @candidates.fetch([ period, consolidation ], []).filter_map { |id| @document.fact(qname, id) }.uniq
        # 同義contextに分散した科目や同一factの重複は読める。
        # 値・精度・単位のいずれかが食い違うときはIDや文書内の順序で選ばない。
        @facts[key] = facts.one? ? facts.first : nil
      end
    end

    # 当期の開始日より前の時点で、企業と連結区分が一致するcontextのfactを、文書の順にすべて返す。
    # 当期末・当期・期首の日付の照合は緩めず、別の式で裏付けて使う処理のために、候補を絞らずに渡す。
    def facts_before_period(qname, consolidation:)
      beginning = @beginnings[consolidation]
      return [] unless beginning
      @contexts.filter_map do |id, context|
        next unless context.entity == @entity && context.consolidation == consolidation
        next unless context.period&.size == 1 && context.period.first < beginning
        @document.fact(qname, id)
      end
    end

    private
      # EDINETの当期期間の宣言を区分ごとに検証する。持株会社の設立等では
      # DEI（提出者の事業年度）と連結会計年度の開始日が異なるため、同一視しない。
      # 宣言がなければDEIを使い、IDを限定せず実日付で候補を照合する。
      def statement_start(context, entity, consolidation, ending)
        return unless context && context.entity == entity && context.consolidation == consolidation
        return unless context.period&.size == 2 && context.period.last == ending
        context.period.first
      end

      def fact_by_id(qname, context)
        period, consolidation = CONTEXT_IDS[context]
        fact(qname, period: period, consolidation: consolidation) if period
      end
  end
end
