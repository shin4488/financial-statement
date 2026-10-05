module FinancialStatements
  # 売上のタグに、合計ではなく内訳だけが付いた書類がある。売上が内訳だと、売上高純利益率などの指標が実際と違ってしまう。
  # 売上を経営指標の要約の売上と照合し、合計であることを確かめる
  module RevenueVerification
    # :matched         … 売上が要約の売上と端数の範囲で一致する
    # :mismatched      … 一致しない（売上が内訳だけになっている、または取り違えている）
    # :revenue_missing … 要約に売上があるのに、損益計算書の売上が取れない
    # :unverifiable    … 要約に売上がなく、照合できない
    def self.status(items) = status_of(items, items["pl.revenue"], items.rounding_errors["pl.revenue"])

    # 売上の取得候補の金額が、要約の売上と一致するか。売上を候補に差し替える前に確かめる
    def self.verified?(items, revenue, rounding_error) = status_of(items, revenue, rounding_error) == :matched

    def self.status_of(items, revenue, revenue_error)
      summary = items["pl.summary_revenue"]
      return :unverifiable if summary.nil?
      return :revenue_missing if revenue.nil?
      errors = items.rounding_errors
      return :matched if RoundingRange.within?(revenue - summary, [ revenue_error, errors["pl.summary_revenue"] ])
      # 売上を営業収益（売上高＋営業収入）とした会社には、要約に売上高だけを載せる会社がある。
      # 売上から本表の営業収入を除いた額が要約の売上高と合えば、売上は売上高と営業収入の合計と確かめられる
      non_sales = items["pl.non_sales_operating_revenue"]
      if non_sales
        non_sales_errors = [ revenue_error, *errors.values_at("pl.non_sales_operating_revenue", "pl.summary_revenue") ]
        return :matched if RoundingRange.within?(revenue - non_sales - summary, non_sales_errors)
      end
      :mismatched
    end
    private_class_method :status_of
  end
end
