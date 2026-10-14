module FinancialStatements
  # 一覧に表示する有報ごとに、同じ企業の過去5年のFCFを並べる。
  # 各年はカードと同じ主たる財務諸表を使い、連結区分が切り替われば注記する。
  # 活動がなく「－」の営業CF・投資CFは、CFのグラフと同じく式が成り立つときだけ0として扱う。
  class FreeCashFlowTrends
    Point = Struct.new(:year, :fiscal_year_start_date, :fiscal_year_end_date,
                       :operating_cf, :investing_cf, :amount, :consolidation_type, keyword_init: true)
    Trend = Struct.new(:renderable, :note, :points, keyword_init: true)

    # targets は推移を作る有報（[TrendTarget]）、history は同じ企業の過去の主の財務諸表（[PastStatement]）。
    # 有報のid → Trend を返す。history を省くと、targets に有報（ARモデル）を受け、過去の財務諸表も読む
    def self.build(targets, history = nil)
      return from_reports(targets) if history.nil?

      new(targets, history).build
    end

    def self.from_reports(reports)
      return {} if reports.empty?

      targets = reports.map do |report|
        TrendTarget.new(report_id: report.id, company_id: report.company_id, fiscal_year_end_date: report.fiscal_year_end_date)
      end
      new(targets, Disclosure::CashFlowHistory.new.load(targets)).build
    end
    private_class_method :from_reports

    def initialize(targets, history)
      @targets = targets
      @history = history
    end

    def build
      grouped = @history.group_by { |statement| [ statement.company_id, statement.fiscal_year_end_date.year ] }

      @targets.to_h do |target|
        end_date = target.fiscal_year_end_date
        points = target.years.map do |year|
          candidates = grouped.fetch([ target.company_id, year ], [])
          # 決算期変更で同一年に複数の有報があれば、カードの対象期以前で最新のものを使う。
          statement = candidates.select { |past| past.fiscal_year_end_date <= end_date }.max_by(&:fiscal_year_end_date)
          point(year, statement)
        end
        renderable = points.any? { |p| !p.amount.nil? }
        [ target.report_id, Trend.new(renderable: renderable,
                                      note: renderable ? consolidation_note(points) : "過去5年のデータがありません",
                                      points: points) ]
      end
    end

    private
      def point(year, statement)
        return Point.new(year: year) unless statement

        values = CashFlowVerification.amounts(statement.amounts)
        operating = values["cf.operating"]
        investing = values["cf.investing"]
        Point.new(year: year,
                  fiscal_year_start_date: statement.fiscal_year_start_date.to_s,
                  fiscal_year_end_date: statement.fiscal_year_end_date.to_s,
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
          type = period.first.consolidation_type == :consolidated ? "連結" : "単体"
          "#{years}年 #{type}"
        end
        "連結区分：#{labels.join(' → ')}"
      end
  end
end
