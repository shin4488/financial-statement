class SecurityReport < ApplicationRecord
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  belongs_to :company

  class << self
    def fetch_company_security_reports(limit:, offset: 0, stock_codes: nil, cash_flow_condition:)
      # 提出日のみのorderだと実行ごとに並び替え順番が異なり得るため、日時を値にもつupdated_atもorderに加えて、何回実行しても同じ並び順となるようにする
      p stock_codes
      p cash_flow_condition
      SecurityReport.eager_load(:company)
        .where(create_conditional_stock_code_clause(stock_codes))
        .where(accounting_standard: "japan_gaap")
        .order(SecurityReport.arel_table[:filing_date].desc.nulls_last, fiscal_year_end_date: :desc, updated_at: :desc)
        .limit(limit)
        .offset(offset)
    end

    private

      # 証券コードが存在する時のみ有効となるWHERE句を作成する
      def create_conditional_stock_code_clause(stock_codes)
        { company: { stock_code: stock_codes.presence }.compact.presence }.compact.presence
      end
  end
end
