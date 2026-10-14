module Ingestion
  module Extractors
    # 取得式を、旧い呼び方（XBRLと標準のコンテキストIDを受け、金額だけを返す evaluate）で評価する。
    # 端数の上限を求めないため、金額にしか答えないXBRLにも使える
    class LegacyExpression
      def initialize(expression)
        @expression = expression
      end

      def evaluate(xbrl, context)
        period, consolidation = Xbrl::ReportingPeriod.period_and_consolidation(context)
        @expression.amount(xbrl, period: period, consolidation: consolidation)
      end
    end
  end
end
