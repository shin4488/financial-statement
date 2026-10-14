module Ingestion
  module Adjustments
    # CFの期首残・期末残は、期末残の取得候補の先頭のタグで取る（IFRSは財政状態計算書と同じ現金及び現金同等物のタグ）。
    # CF計算書の残高がその額と違う会社は、CF計算書の残高を2番目以降の標準タグで開示する。ただし、そのタグを調整後の期首残高など
    # ほかの行に付ける会社もあるため、期首残・期末残をそのタグの額にしたときにCFの式が端数の範囲で成り立つ場合だけ差し替える。
    # 経営指標の要約のタグは本表の残高ではないため候補にしない
    class CashFlowStatementBalance
      # 差し替える科目と、期末残の候補で値を引く期間（期首残は前期末）
      BALANCES = { "cf.cash_end" => :instant, "cf.cash_begin" => :prior_instant }.freeze

      def self.apply(amounts, mapping:, source:, consolidation:)
        expression = mapping.expression("cf.cash_end")
        return unless expression && amounts.key?("cf.cash_end")
        Expressions.statement_candidates(expression).drop(1).each do |candidate|
          trial = amounts.dup
          BALANCES.each do |code, period|
            measured = candidate.evaluate(source, period: period, consolidation: consolidation)
            next if measured.nil?
            trial.store(code, measured.amount, measured.rounding_error)
          end
          # 試算は端数を比べず、金額が変わらなければ差し替えない
          next if trial.same_values?(amounts) || FinancialStatements::CashFlowVerification.mismatch(trial)
          trial.slice(*BALANCES.keys).each { |code, amount| amounts.store(code, amount, trial.rounding_errors[code]) }
          return
        end
      end
    end
  end
end
