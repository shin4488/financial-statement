module FinancialStatements
  # 一覧に表示する有報を起点に、同じ企業の過去5年をまとめて取得する。
  # 各年はカードと同じ主たる財務諸表を使い、連結区分が切り替われば注記する。
  # CFの式に使う科目だけを一括取得し、カード数に比例した追加クエリを発生させない。
  # 活動がなく「－」の営業CF・投資CFは、CFのグラフと同じく式が成り立つときだけ0として扱う。
  class FreeCashFlowTrends
    YEARS = 5
    CODES = (CashFlowVerification::FLOWS + CashFlowVerification::ADJUSTMENTS + [ CashFlowVerification::CLOSING ]).freeze
    Point = Struct.new(:year, :fiscal_year_start_date, :fiscal_year_end_date,
                       :operating_cf, :investing_cf, :amount, :consolidation_type, keyword_init: true)
    Trend = Struct.new(:renderable, :note, :points, keyword_init: true)

    def self.build(reports)
      return {} if reports.empty?

      new(reports).build
    end

    def initialize(reports)
      @reports = reports
    end

    def build
      statements = historical_statements
      amounts = amounts_by_statement(statements)
      grouped = statements.group_by do |statement|
        [ statement.report.company_id, statement.report.fiscal_year_end_date.year ]
      end

      @reports.to_h do |report|
        end_date = report.fiscal_year_end_date
        points = ((end_date.year - YEARS + 1)..end_date.year).map do |year|
          candidates = grouped.fetch([ report.company_id, year ], [])
          # 決算期変更で同一年に複数の有報があれば、カードの対象期以前で最新のものを使う。
          statement = candidates.select { |fs| fs.report.fiscal_year_end_date <= end_date }
                                .max_by { |fs| fs.report.fiscal_year_end_date }
          point(year, statement, amounts)
        end
        renderable = points.any? { |p| !p.amount.nil? }
        [ report.id, Trend.new(renderable: renderable,
                               note: renderable ? consolidation_note(points) : "過去5年のデータがありません",
                               points: points) ]
      end
    end

    private
      def historical_statements
        years = @reports.map { |report| report.fiscal_year_end_date.year }
        Disclosure::FinancialStatement.joins(:report)
          .where(reports: {
            company_id: @reports.map(&:company_id).uniq,
            fiscal_year_end_date: Date.new(years.min - YEARS + 1, 1, 1)..Date.new(years.max, 12, 31)
          })
          .where(is_primary: true)
          .preload(:report).to_a
      end

      def amounts_by_statement(statements)
        return {} if statements.empty?

        Disclosure::FinancialStatementItem.where(financial_statement_id: statements.map(&:id), item_code: CODES)
          .pluck(:financial_statement_id, :item_code, :amount, :rounding_error)
          .each_with_object({}) do |(id, code, amount, rounding_error), result|
            amounts = (result[id] ||= Amounts.new)
            amounts[code] = amount
            amounts.rounding_errors[code] = rounding_error
          end
      end

      def point(year, statement, amounts)
        return Point.new(year: year) unless statement

        values = CashFlowVerification.amounts(amounts.fetch(statement.id, Amounts.new))
        operating = values["cf.operating"]
        investing = values["cf.investing"]
        Point.new(year: year,
                  fiscal_year_start_date: statement.report.fiscal_year_start_date.to_s,
                  fiscal_year_end_date: statement.report.fiscal_year_end_date.to_s,
                  operating_cf: operating, investing_cf: investing,
                  amount: operating && investing ? operating + investing : nil,
                  consolidation_type: statement.consolidation_type)
      end

      def consolidation_note(points)
        available = points.select { |point| !point.amount.nil? }
        return nil if available.map(&:consolidation_type).uniq.one?

        periods = available.chunk_while do |previous, following|
          previous.consolidation_type == following.consolidation_type && following.year == previous.year + 1
        end
        labels = periods.map do |period|
          years = period.first.year == period.last.year ? period.first.year.to_s : "#{period.first.year}～#{period.last.year}"
          type = period.first.consolidation_type == "consolidated" ? "連結" : "単体"
          "#{years}年 #{type}"
        end
        "連結区分：#{labels.join(' → ')}"
      end
  end
end
