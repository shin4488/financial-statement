module Disclosure
  class FinancialStatement < ApplicationRecord
    self.table_name = "financial_statements"

    belongs_to :report, class_name: "Disclosure::Report"
    # dependent: :delete_all — 取込の科目総入れ替え（items.delete_all）で行を物理削除するため。
    # 指定がないと関連のdelete_allは外部キーのNULL化になり、NOT NULL制約に違反する
    has_many :items, class_name: "Disclosure::FinancialStatementItem",
             foreign_key: :financial_statement_id, dependent: :delete_all

    enum :consolidation_type, { consolidated: 0, non_consolidated: 1 }
    enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }, prefix: true

    validates :presentation_format, inclusion: { in: FinancialStatements::Formats::ALL }

    # グラフの説明文を年度で分ける形式があるため、グラフ作成処理に決算日を渡す
    delegate :fiscal_year_end_date, to: :report

    # 科目ごとの金額と端数の表（FinancialStatements::Amounts）。グラフ・指標へは to_statement_data で複製して渡す。
    # preload済みなら科目と精度をメモリから取得する
    def items_hash
      @items_hash ||= items.each_with_object(FinancialStatements::Amounts.new) do |item, amounts|
        amounts.store(item.item_code, item.amount, item.rounding_error)
      end
    end

    # グラフ・指標に渡す、DBに依存しない値
    def to_statement_data
      FinancialStatements::StatementData.new(
        consolidation_type: consolidation_type, accounting_standard: accounting_standard,
        presentation_format: presentation_format, amounts: items_hash,
        disclosed_roe: disclosed_roe, fiscal_year_end_date: fiscal_year_end_date)
    end
  end
end
