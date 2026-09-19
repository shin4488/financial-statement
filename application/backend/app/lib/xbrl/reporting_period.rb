module Xbrl
  # 既存Extractorの期間名は「当期末・当期・期首」を指定する検索キーとして扱う。
  # 元文書のIDへの別名付けではなく、全書類でcontextの内容を照合する読み取り専用ビュー。
  class ReportingPeriod
    CONSOLIDATIONS = { "" => :consolidated, "_NonConsolidatedMember" => :non_consolidated }.freeze

    def initialize(document, contexts:, start_date:, end_date:)
      @document = document
      @candidates = {}
      @facts = {}
      beginning = Context.date(start_date)
      ending = Context.date(end_date)
      entity = contexts["FilingDateInstant"]&.entity
      return unless beginning && ending && beginning <= ending && entity

      index = contexts.group_by { |_, context| [ context.entity, context.period, context.consolidation ] }
      CONSOLIDATIONS.each do |suffix, consolidation|
        start = statement_start(contexts["CurrentYearDuration#{suffix}"], entity, consolidation, ending) || beginning
        periods = { "CurrentYearInstant" => [ ending ], "CurrentYearDuration" => [ start, ending ],
                    "Prior1YearInstant" => [ start - 1 ] }
        periods.each do |name, period|
          @candidates["#{name}#{suffix}"] = index.fetch([ entity, period, consolidation ], []).map(&:first)
        end
      end
    end

    def money(qname, context) = fact(qname, context)&.money
    def text(qname, context) = fact(qname, context)&.value
    def rounding_error(qname, context) = fact(qname, context)&.rounding_error

    private
      # EDINETの当期期間の宣言を区分ごとに検証する。持株会社の設立等では
      # DEI（提出者の事業年度）と連結会計年度の開始日が異なるため、同一視しない。
      # 宣言がなければDEIを使い、IDを限定せず実日付で候補を照合する。
      def statement_start(context, entity, consolidation, ending)
        return unless context && context.entity == entity && context.consolidation == consolidation
        return unless context.period&.size == 2 && context.period.last == ending
        context.period.first
      end

      def fact(qname, context)
        @facts.fetch([ qname, context ]) do |key|
          facts = @candidates.fetch(context, []).filter_map { |id| @document.fact(qname, id) }.uniq
          # 同義contextに分散した科目や同一factの重複は読める。
          # 値・精度・単位のいずれかが食い違うときはIDや文書内の順序で選ばない。
          @facts[key] = facts.one? ? facts.first : nil
        end
      end
  end
end
