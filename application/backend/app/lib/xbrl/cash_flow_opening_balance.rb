module Xbrl
  # 期首現金の照合は、取込の補正ルール Ingestion::Adjustments::OpeningCash が持つ。
  # ここは照合を渡すだけの入口で、XBRL読取からは呼ばない（XBRL読取は取込を参照しない）。
  class CashFlowOpeningBalance
    def self.reconcile(opening:, closing:, change:, adjustments:)
      Ingestion::Adjustments::OpeningCash.reconcile(opening: opening, closing: closing, change: change, adjustments: adjustments)
    end
  end
end
