module Disclosure
  class FinancialStatementItem < ApplicationRecord
    self.table_name = "financial_statement_items"

    belongs_to :financial_statement, class_name: "Disclosure::FinancialStatement"

    validates :item_code, inclusion: { in: FinancialStatements::ItemCatalog::ALL }
    validates :amount, presence: true
  end
end
