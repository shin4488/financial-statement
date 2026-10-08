module Ingestion
  # 取り込んだ値が、同じ書類のほかの実際の値と合うかを照合し、合わないものを警告として返す。
  # 売上は、要約の売上と一致する取得候補があれば取込のときに差し替えている（Extractors::Base）ため、
  # ここで合わないのは、候補のどれでも確かめられなかったものだけになる。
  # ここでは保存する値やグラフを直さない。直し方は人が原本で確かめて決めるため、知らせるだけにする。
  # 文言は照合の種類ごとに固定し、書類ごとの金額は付加情報にする（通知先で種類ごとにまとまり、書類ごとに増えない）
  module Reconciliation
    REVENUE_MISMATCH = "revenue does not match summary of business results".freeze
    REVENUE_MISSING = "revenue missing although summary of business results has revenue".freeze
    # 描いたPLの費用が、保存した科目どうしの式を端数の範囲で満たさない（タグで費用を説明できない）。
    # 式は描き方で違い、グラフ作成処理が決める（日本基準は費用・営業利益と売上、IFRSは積まなかった営業費用と売上原価・販管費）
    PROFIT_LOSS_MISMATCH = "profit and loss chart expenses do not reconcile".freeze
    # 描いたBSで、借方の科目の合計が資産合計と、または資産合計が負債合計＋純資産合計と、端数の範囲で一致しない
    BALANCE_SHEET_MISMATCH = "balance sheet chart does not reconcile with totals".freeze
    # 期首残＋各CF＋換算差額など＝期末残が、行がない項目を0とみなしても端数の範囲で成り立たない
    CASH_FLOW_MISMATCH = "cash flow does not reconcile with closing balance".freeze

    Warning = Data.define(:message, :amounts)

    def self.warnings(items, format)
      [
        revenue_warning(items),
        chart_warning(PROFIT_LOSS_MISMATCH, Charts::BuilderRegistry::PL[format], items),
        chart_warning(BALANCE_SHEET_MISMATCH, Charts::BuilderRegistry::BS[format], items),
        (chart_warning(CASH_FLOW_MISMATCH, Charts::Builders::CashFlow, items) if reads_cash_flow_adjustments?(format))
      ].compact
    end

    def self.revenue_warning(items)
      case FinancialStatements::RevenueVerification.status(items)
      when :mismatched then Warning.new(REVENUE_MISMATCH, items.slice("pl.revenue", "pl.summary_revenue"))
      when :revenue_missing then Warning.new(REVENUE_MISSING, items.slice("pl.summary_revenue"))
      end
    end

    # グラフに描く科目の組み合わせはグラフ作成処理が選ぶため、照合もその描き方で行う
    def self.chart_warning(message, builder, items)
      amounts = builder&.new(items)&.mismatch
      Warning.new(message, amounts) if amounts
    end

    # 経営指標の要約だけで作る形式は、要約に換算差額などの行がないため、換算差額がある年はCFの式が合わない。
    # 原本で直せる誤りではないため、式の行を読む形式だけを照合する
    def self.reads_cash_flow_adjustments?(format)
      codes = FormatRegistry.extractor_for(format)&.item_codes || []
      codes.intersect?(FinancialStatements::CashFlowVerification::ADJUSTMENTS)
    end
    private_class_method :revenue_warning, :chart_warning, :reads_cash_flow_adjustments?
  end
end
