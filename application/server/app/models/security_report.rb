class SecurityReport < ApplicationRecord
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  belongs_to :company

  class << self
    def fetch_company_security_reports(limit:, offset: 0)
      # 提出日のみのorderだと実行ごとに並び替え順番が異なり得るため、日時を値にもつupdated_atもorderに加えて、何回実行しても同じ並び順となるようにする
      SecurityReport.eager_load(:company)
        .where(accounting_standard: "japan_gaap")
        .order(SecurityReport.arel_table[:filing_date].desc.nulls_last, updated_at: :desc)
        .limit(limit)
        .offset(offset)
    end
  end
end
