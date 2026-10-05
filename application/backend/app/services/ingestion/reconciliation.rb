module Ingestion
  # 取り込んだ値が、同じ書類のほかの実際の値と合うかを照合し、合わないものを警告として返す。
  # 保存する値やグラフは照合の結果で直さない。直し方は人が原本で確かめて決めるため、知らせるだけにする。
  # 文言は照合の種類ごとに固定し、書類ごとの金額は付加情報にする（通知先で種類ごとにまとまり、書類ごとに増えない）
  module Reconciliation
    REVENUE_MISMATCH = "revenue does not match summary of business results".freeze
    REVENUE_MISSING = "revenue missing although summary of business results has revenue".freeze

    Warning = Data.define(:message, :amounts)

    def self.warnings(items)
      case FinancialStatements::RevenueVerification.status(items)
      when :mismatched then [ Warning.new(REVENUE_MISMATCH, items.slice("pl.revenue", "pl.summary_revenue")) ]
      when :revenue_missing then [ Warning.new(REVENUE_MISSING, items.slice("pl.summary_revenue")) ]
      else []
      end
    end
  end
end
