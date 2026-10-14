module Disclosure
  # FCF推移を作る有報と同じ企業について、推移に並べる年の主の財務諸表を読む。
  # CFの式に使う科目だけを一括で読み、有報の件数に比例した問い合わせを出さない
  class CashFlowHistory
    CODES = (FinancialStatements::CashFlowVerification::FLOWS + FinancialStatements::CashFlowVerification::ADJUSTMENTS +
             [ FinancialStatements::CashFlowVerification::CLOSING ]).freeze

    # targets: [FinancialStatements::TrendTarget] → [FinancialStatements::PastStatement]
    def load(targets)
      return [] if targets.empty?

      statements = primary_statements(targets)
      amounts = amounts_by_statement(statements)
      statements.map do |statement|
        report = statement.report
        FinancialStatements::PastStatement.new(
          company_id: report.company_id,
          fiscal_year_start_date: report.fiscal_year_start_date, fiscal_year_end_date: report.fiscal_year_end_date,
          consolidation_type: statement.consolidation_type,
          amounts: amounts.fetch(statement.id) { FinancialStatements::Amounts.new })
      end
    end

    private
      def primary_statements(targets)
        first_year = targets.map { |target| target.years.first }.min
        last_year = targets.map { |target| target.years.last }.max
        Disclosure::FinancialStatement.joins(:report)
          .where(reports: {
            company_id: targets.map(&:company_id).uniq,
            fiscal_year_end_date: Date.new(first_year, 1, 1)..Date.new(last_year, 12, 31)
          })
          .where(is_primary: true)
          .preload(:report).to_a
      end

      def amounts_by_statement(statements)
        return {} if statements.empty?

        Disclosure::FinancialStatementItem.where(financial_statement_id: statements.map(&:id), item_code: CODES)
          .pluck(:financial_statement_id, :item_code, :amount, :rounding_error)
          .each_with_object({}) do |(id, code, amount, rounding_error), result|
            (result[id] ||= FinancialStatements::Amounts.new).store(code, amount, rounding_error)
          end
      end
  end
end
