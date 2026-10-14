module Ingestion
  # 補正ルール。科目をすべて評価した後に、同じ書類のほかの値と照合して補う・差し替える。
  # 前のルールの結果を次のルールが使うため、適用の順をこの一覧で固定する。
  # 補正ルールに共有する実装はないため、基底クラスを作らず、apply(amounts, mapping:, source:, consolidation:) を揃える。
  # 当てはまらなければ何もせず、当てはまれば amounts を直接更新する（mapping・source・consolidation は Ingestion::StatementExtractor と同じ）
  module Adjustments
    ALL = [ OpeningCash, CashFlowStatementBalance, RevenueCandidate, ZeroRevenue ].freeze
  end
end
