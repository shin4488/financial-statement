module Ingestion
  module Extractors
    # 自己資本の取得式（Ingestion::Expressions::JgaapOwnersEquity）を、evaluate(xbrl, 標準のコンテキストID) で金額を返す形で呼ぶ
    class JgaapOwnersEquity
      def evaluate(xbrl, context) = Base.wrap(Expressions::JgaapOwnersEquity.new).evaluate(xbrl, context)
    end
  end
end
