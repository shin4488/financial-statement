module FinancialStatements
  # 財務諸表の表示形式（presentation_format）の一覧。DBに保存する値で、取込・保存・グラフが同じ名前で形式を表す
  module Formats
    JGAAP_GENERAL   = "jgaap_general"
    JGAAP_BANK      = "jgaap_bank"
    JGAAP_INSURANCE = "jgaap_insurance"
    IFRS_CLASSIFIED = "ifrs_classified"
    IFRS_LIQUIDITY  = "ifrs_liquidity"
    IFRS_SUMMARY    = "ifrs_summary"
    USGAAP_SUMMARY  = "usgaap_summary"
    UNSUPPORTED     = "unsupported" # 対応する形式がない財務諸表。形式を足したら、再取込タスクで取り直す

    ALL = [
      JGAAP_GENERAL, JGAAP_BANK, JGAAP_INSURANCE, IFRS_CLASSIFIED, IFRS_LIQUIDITY, IFRS_SUMMARY, USGAAP_SUMMARY, UNSUPPORTED
    ].freeze
  end
end
