module UseCases
  # 有報の一覧を検索し、有報ごとに主の財務諸表からグラフと指標を作る。FCF推移は要求されたときだけ作る
  class ListFinancialReports
    # report は有報（ARモデル）、statement は主の財務諸表の値（FinancialStatements::StatementData）
    Entry = Data.define(:report, :statement, :charts, :indicators, :free_cash_flow_trend)

    # cf_signs: { operating: :positive|:negative|nil, ... }。
    # with_trend が偽なら、FCF推移を作らず、過去の財務諸表も読まない（free_cash_flow_trend は nil）
    def call(limit:, offset:, stock_codes:, cf_signs:, with_trend:)
      reports = Disclosure::SearchQuery.new.call(limit: limit, offset: offset, stock_codes: stock_codes, cf_signs: cf_signs)
      trends = with_trend ? free_cash_flow_trends(reports) : {}
      reports.map do |report|
        statement = report.primary_financial_statement.to_statement_data
        Entry.new(report: report, statement: statement,
                  charts: Charts::BuilderRegistry.build_all(statement),
                  indicators: FinancialStatements::Indicators.build(statement),
                  free_cash_flow_trend: trends[report.id])
      end
    end

    private
      def free_cash_flow_trends(reports)
        return {} if reports.empty?

        targets = reports.map do |report|
          FinancialStatements::TrendTarget.new(report_id: report.id, company_id: report.company_id,
                                               fiscal_year_end_date: report.fiscal_year_end_date)
        end
        FinancialStatements::FreeCashFlowTrends.build(targets, Disclosure::CashFlowHistory.new.load(targets))
      end
  end
end
