module Disclosure
  class Report < ApplicationRecord
    self.table_name = "reports"

    belongs_to :company, class_name: "Disclosure::Company"
    has_many :financial_statements, class_name: "Disclosure::FinancialStatement", foreign_key: :report_id
    has_one :primary_financial_statement, -> { where(is_primary: true) },
            class_name: "Disclosure::FinancialStatement", foreign_key: :report_id

    enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  end
end
