module FinancialStatements
  # 売上のタグに、合計ではなく内訳だけが付いた書類がある。売上が内訳だと、売上高純利益率などの指標が実際と違ってしまう。
  # 売上を経営指標の要約の売上と照合し、合計であることを確かめる
  module RevenueVerification
    # :matched         … 売上が要約の売上と端数の範囲で一致する
    # :mismatched      … 一致しない（売上が内訳だけになっている、または取り違えている）
    # :revenue_missing … 要約に売上があるのに、損益計算書の売上が取れない
    # :unverifiable    … 要約に売上がなく、照合できない
    def self.status(items)
      revenue, summary = items.values_at("pl.revenue", "pl.summary_revenue")
      return :unverifiable if summary.nil?
      return :revenue_missing if revenue.nil?
      return :matched if balanced?(items, revenue - summary, %w[pl.revenue pl.summary_revenue])
      # 売上を営業収益（売上高＋営業収入）とした会社には、要約に売上高だけを載せる会社がある。
      # 売上から本表の営業収入を除いた額が要約の売上高と合えば、売上は売上高と営業収入の合計と確かめられる
      non_sales = items["pl.non_sales_operating_revenue"]
      codes = %w[pl.revenue pl.non_sales_operating_revenue pl.summary_revenue]
      return :matched if non_sales && balanced?(items, revenue - non_sales - summary, codes)
      :mismatched
    end

    def self.balanced?(items, difference, codes)
      RoundingRange.within?(difference, items.rounding_errors.values_at(*codes))
    end
    private_class_method :balanced?
  end
end
