module Ingestion
  module Adjustments
    # 売上のタグに、合計ではなく内訳だけが付いた書類がある（標準タグの売上高が製品売上高だけで、
    # 合計の事業収益は企業拡張タグに付けるなど）。売上が経営指標の要約の売上と合わないときは、
    # 売上の取得候補のうち要約と一致するものを売上にする。どれも合わなければ、取込の照合で警告する。
    # 要約のタグ（jpcrp_cor）は照合の相手なので候補にしない。要約の値そのものを売上にすると、照合の意味がなくなるため。
    # 通常の取得候補をすべて試した後に、差し替えのときだけ使う候補（対応表の replacements:）を順に試す
    class RevenueCandidate
      def self.apply(amounts, mapping:, source:, consolidation:)
        expression = mapping.expression("pl.revenue")
        return unless expression && FinancialStatements::RevenueVerification.status(amounts) == :mismatched
        (Expressions.statement_candidates(expression) + mapping.replacements("pl.revenue")).each do |candidate|
          measured = candidate.evaluate(source, period: :duration, consolidation: consolidation)
          next if measured.nil?
          next unless FinancialStatements::RevenueVerification.verified?(amounts, measured.amount, measured.rounding_error)
          amounts.store("pl.revenue", measured.amount, measured.rounding_error)
          return
        end
      end
    end
  end
end
