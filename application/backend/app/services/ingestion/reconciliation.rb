module Ingestion
  # 取り込んだ値の照合は UseCases::StatementInspection が持ち、文言は UseCases::IngestionNotices が定義する。
  # ここは照合の結果を警告の形で返すだけの入口
  module Reconciliation
    REVENUE_MISMATCH = UseCases::IngestionNotices.text(:revenue_mismatch)
    REVENUE_MISSING = UseCases::IngestionNotices.text(:revenue_missing)
    PROFIT_LOSS_MISMATCH = UseCases::IngestionNotices.text(:profit_loss_mismatch)
    BALANCE_SHEET_MISMATCH = UseCases::IngestionNotices.text(:balance_sheet_mismatch)
    CASH_FLOW_MISMATCH = UseCases::IngestionNotices.text(:cash_flow_mismatch)

    Warning = Data.define(:message, :amounts)

    def self.warnings(items, format)
      UseCases::StatementInspection.mismatches(items, format).map do |kind, amounts|
        Warning.new(UseCases::IngestionNotices.text(kind), amounts)
      end
    end
  end
end
