module Ingestion
  module Adjustments
    # CFの期首残だけは、当期の増減額などで原本の期首の残高を裏付けられる。
    # 期首の日付が合わずに取れなかったときは、CFの式を満たす過去の時点の残高（日本基準のタグ・円）が1つに決まる場合だけ、その開示額を期首残にする。
    # 総資産・自己資本の期首は式で裏付けられないため、この補完を使わない
    class OpeningCash
      BALANCE = "jppfs_cor:CashAndCashEquivalents".freeze
      CHANGE = "jppfs_cor:NetIncreaseDecreaseInCashAndCashEquivalents".freeze
      # 新規連結・連結範囲の変更による増減
      SCOPE_CHANGES = %w[
        jppfs_cor:IncreaseInCashAndCashEquivalentsFromNewlyConsolidatedSubsidiaryCCE
        jppfs_cor:IncreaseDecreaseInCashAndCashEquivalentsResultingFromChangeOfScopeOfConsolidationCCE
      ].freeze

      # 期首残がなく期末残があるときだけ補う。使うタグはこのルールが持つため、対応表（mapping）は使わない
      def self.apply(amounts, mapping:, source:, consolidation:)
        return if amounts.key?("cf.cash_begin") || !amounts.key?("cf.cash_end")
        # 過去の時点のfactを返せるのは Xbrl::ReportingPeriod だけ。Xbrl::Document やその代役を直接渡したときは補完しない
        return unless source.respond_to?(:facts_before_period)
        opening = find_opening(source, consolidation, amounts["cf.cash_end"])
        amounts.store("cf.cash_begin", opening.money, opening.rounding_error) if opening
      end

      # 期首 + 当期増減 + 連結範囲変更等 = 期末を、同一通貨・開示精度で照合する。
      # 計算値で原本を置き換えず、式を満たす原本の期首額だけを返す。
      def self.reconcile(opening:, closing:, change:, adjustments:)
        facts = [ opening, closing, change, *adjustments ]
        return if facts.any?(&:nil?)
        return unless facts.map(&:unit).uniq == [ Xbrl::Fact::JPY ]
        return if facts.any? { |fact| fact.money.nil? }
        return if opening.money.negative? || closing.money.negative?

        difference = closing.money - opening.money - change.money - adjustments.sum(&:money)
        opening if FinancialStatements::RoundingRange.within?(difference, facts.map(&:rounding_error))
      end

      # 原本の期末残が抽出した期末残と同じときだけ探す。
      # 数年前の残高を無条件には使わず、CFの式を満たす候補が1つに決まるときだけ採用する
      def self.find_opening(source, consolidation, closing_amount)
        closing = source.fact(BALANCE, period: :instant, consolidation: consolidation)
        return unless closing && closing.money == closing_amount
        change = source.fact(CHANGE, period: :duration, consolidation: consolidation)
        adjustments = SCOPE_CHANGES.filter_map { |qname| source.fact(qname, period: :duration, consolidation: consolidation) }
        matches = source.facts_before_period(BALANCE, consolidation: consolidation).filter_map do |opening|
          reconcile(opening: opening, closing: closing, change: change, adjustments: adjustments)
        end.uniq
        matches.first if matches.one?
      end
      private_class_method :reconcile, :find_opening
    end
  end
end
