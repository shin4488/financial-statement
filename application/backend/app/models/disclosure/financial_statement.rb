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

    # モデル→Ingestion名前空間への参照になるが許容する（形式の正当な値一覧の管理場所を
    # FormatRegistry 1箇所に限定する方を優先。二重管理にすると形式追加時に片方を忘れる）
    validates :presentation_format, inclusion: { in: Ingestion::FormatRegistry::ALL }

    # {item_code => amount} のハッシュ。ChartBuilderへの入力形式。
    # メモ化する理由: 1つの財務諸表からBS/PL/CFの3つのBuilderが呼ばれるため、
    # クエリを1回に抑える（preload済みならpluckはメモリ上で解決される）
    def items_hash
      @items_hash ||= items.pluck(:item_code, :amount).to_h
    end
  end
end
