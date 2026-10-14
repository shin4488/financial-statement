module Ingestion
  module Adjustments
    # 売上がない会社（創薬ベンチャーなど）は、経営指標の要約の売上を「－」で開示し、損益計算書では売上の行を「－」にするか、
    # 前期も売上がなければ行そのものを載せない。本表の売上の取得候補のどれからも売上が取れず、要約の売上が「－」のときに、
    # 売上0と確かめられたとして両方に0を保存する。要約に売上の行がないときは、売上が一覧にない要素名で開示されている
    # おそれがあり、0にすると実際の売上と違う値になるため保存しない。
    # 経営指標の要約だけで作る形式は、本表で売上がないことを確かめられないため対象にしない。
    # 連結初年度で連結の損益計算書を作っていない書類も、売上を含むすべての行が「－」になるため、
    # 損益の値がある（損益計算書を作っている）ときだけ確かめる
    class ZeroRevenue
      PROFITS = %w[pl.operating_profit pl.profit_before_tax pl.profit].freeze

      def self.apply(amounts, mapping:, source:, consolidation:)
        revenue, summary = mapping.expression("pl.revenue"), mapping.expression("pl.summary_revenue")
        return unless revenue && summary && Expressions.statement_candidates(revenue).any?
        return if amounts.key?("pl.revenue") || amounts.key?("pl.summary_revenue")
        return unless PROFITS.any? { |code| amounts.key?(code) }
        return unless summary.blank?(source, period: :duration, consolidation: consolidation)
        %w[pl.revenue pl.summary_revenue].each { |code| amounts.store(code, 0, 0.to_d) }
      end
    end
  end
end
