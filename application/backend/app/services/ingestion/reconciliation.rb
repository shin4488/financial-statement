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

    Warning = Data.define(:message, :amounts)

    def self.warnings(items, format)
      [ revenue_warning(items), profit_loss_warning(items, format) ].compact
    end

    def self.revenue_warning(items)
      case FinancialStatements::RevenueVerification.status(items)
      when :mismatched then Warning.new(REVENUE_MISMATCH, items.slice("pl.revenue", "pl.summary_revenue"))
      when :revenue_missing then Warning.new(REVENUE_MISSING, items.slice("pl.summary_revenue"))
      end
    end

    # グラフに描く費用の組み合わせはグラフ作成処理が選ぶため、照合もその選んだ組み合わせで行う
    def self.profit_loss_warning(items, format)
      amounts = Charts::BuilderRegistry::PL[format]&.new(items)&.mismatch
      Warning.new(PROFIT_LOSS_MISMATCH, amounts) if amounts
    end
    private_class_method :revenue_warning, :profit_loss_warning
  end
end
