module FinancialStatements
  # FCF推移を作る有報（一覧のカード1枚）。推移には、決算日の暦年までの YEARS 年を並べる。
  # 過去の財務諸表を読む範囲と推移の年を、同じ定義から求める
  class TrendTarget < Data.define(:report_id, :company_id, :fiscal_year_end_date)
    YEARS = 5

    # 推移に並べる暦年（古い順）
    def years = (fiscal_year_end_date.year - YEARS + 1)..fiscal_year_end_date.year
  end
end
