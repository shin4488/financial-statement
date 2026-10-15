module Charts
  module Builders
    # 組み立ての補助は継承せず、部品（TwoSidedChart・Segments・Tolerance）として使う
    class Base
      # 「描けない」の共通文言。個別の理由を説明できる形式（ifrs_summaryなど）だけ独自文言を使う
      NO_DATA_NOTE = "データがない、または表示対応していないデータです。".freeze

      # fiscal_year_end_date: 決算日（Date）。説明文を年度で分ける形式だけが使う。分からなければnil
      def initialize(items, fiscal_year_end_date: nil)
        @items = items # {item_code => amount} (FinancialStatements::StatementData#amounts など)
        @fiscal_year_end_date = fiscal_year_end_date
      end

      # 描くグラフが、保存した科目どうしの式を端数の範囲で満たさないときの、式に使った金額（{科目コード => 金額}）。
      # 取込のときの点検（UseCases::StatementInspection）がSentryへの警告に使う。式どおりに描くか、描かないときはnil。
      # 照合する式は描き方で違うため、照合するBuilderが上書きする
      def mismatch = nil

      private
        def val(code) = @items[code]

        def no_data_note(statement_label) = "#{statement_label}: #{NO_DATA_NOTE}"
    end
  end
end
