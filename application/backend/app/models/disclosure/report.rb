module Disclosure
  class Report < ApplicationRecord
    self.table_name = "reports"

    belongs_to :company, class_name: "Disclosure::Company"
    has_many :financial_statements, class_name: "Disclosure::FinancialStatement", foreign_key: :report_id
    # 条件付きの関連は逆向きの関連を自動で設定しないため、明示する。一覧で先読みした財務諸表から決算日を引くときに、
    # 書類ごとの問い合わせを出さないため
    has_one :primary_financial_statement, -> { where(is_primary: true) },
            class_name: "Disclosure::FinancialStatement", foreign_key: :report_id, inverse_of: :report

    enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  end
end
