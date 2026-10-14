module Ingestion
  # 形式によらない抽出器。形式ごとの違いは対応表として受け取り、科目をすべて評価してから補正ルールを一覧の順に適用する
  class StatementExtractor
    # mapping は、評価する科目（code・period・expression）の一覧 items と、科目コードから取得式を引く expression(code) を持つ。
    # source・consolidation は取得式に渡す値（Ingestion::Expressions）
    def self.amounts(mapping, source:, consolidation:)
      amounts = FinancialStatements::Amounts.new
      # 取れなかった科目はキーごと入れない（「開示なし」をnilや0でなくキーの不存在で表す。DBの「行の不存在=開示なし」と対になる規約）
      mapping.items.each do |item|
        measured = item.expression.evaluate(source, period: item.period, consolidation: consolidation)
        amounts.store(item.code, measured.amount, measured.rounding_error) if measured
      end
      Adjustments::ALL.each { |adjustment| adjustment.apply(amounts, mapping: mapping, source: source, consolidation: consolidation) }
      amounts
    end
  end
end
