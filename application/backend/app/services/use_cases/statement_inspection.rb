module UseCases
  # 取り込んだ財務諸表の点検。資産合計の欠落と、同じ書類のほかの実際の値・グラフの検算との照合から、通知を作る（送らない）。
  # 取込の対応表（形式が作る科目）とグラフの両方を使うため、ユースケースに置く。
  # 売上は、要約の売上と一致する取得候補があれば取込のときに差し替えている（補正ルール Ingestion::Adjustments::RevenueCandidate）ため、
  # ここで合わないのは、候補のどれでも確かめられなかったものだけになる。
  # ここでは保存する値やグラフを直さない。直し方は人が原本で確かめて決めるため、知らせるだけにする
  module StatementInspection
    module_function

    # 画面に出す（主の）財務諸表だけを点検する。並びは送る順（資産合計の欠落 → 売上 → PL → BS → CF）。
    # 照合は資産合計の欠落の通知を取り出した後に計算する（照合の途中で例外になっても、資産合計の欠落を先に送れるように）
    def notices(statement_data, primary:, doc_id:)
      Enumerator.new do |found|
        next unless primary

        amounts = statement_data.amounts
        format = statement_data.presentation_format
        found << IngestionNotices.build(:missing_assets, doc_id: doc_id, presentation_format: format) if missing_assets?(amounts, format)
        mismatches(amounts, format).each do |kind, compared|
          found << IngestionNotices.build(kind, doc_id: doc_id, consolidation_type: statement_data.consolidation_type,
                                                presentation_format: format, amounts: compared)
        end
      end
    end

    # 照合で合わなかった通知の種類と、照合に使った金額の組の並び（売上 → PL → BS → CF の順）
    def mismatches(amounts, format)
      [
        revenue_mismatch(amounts),
        chart_mismatch(:profit_loss_mismatch, Charts::BuilderRegistry::PL[format], amounts),
        chart_mismatch(:balance_sheet_mismatch, Charts::BuilderRegistry::BS[format], amounts),
        (chart_mismatch(:cash_flow_mismatch, Charts::Builders::CashFlow, amounts) if reads_cash_flow_adjustments?(format))
      ].compact
    end

    # 主対象なのに資産合計すら取れないのは形式判定ミスの可能性が高い。
    # 取込自体は継続する（unsupported形式や科目欠落はエラーではないため）。
    # 「BSを抽出する形式か」は個別の形式名でなく形式の対応表に聞く
    # （BSを抽出しない形式を増やしてもここを触らずに済む）
    def missing_assets?(amounts, format)
      return false if amounts.key?("bs.assets")
      !!Ingestion::Mappings.for(format)&.item_codes&.include?("bs.assets")
    end

    def revenue_mismatch(amounts)
      case FinancialStatements::RevenueVerification.status(amounts)
      when :mismatched then [ :revenue_mismatch, amounts.slice("pl.revenue", "pl.summary_revenue") ]
      when :revenue_missing then [ :revenue_missing, amounts.slice("pl.summary_revenue") ]
      end
    end

    # グラフに描く科目の組み合わせはグラフ作成処理が選ぶため、照合もその描き方で行う
    def chart_mismatch(kind, builder, amounts)
      compared = builder&.new(amounts)&.mismatch
      [ kind, compared ] if compared
    end

    # 経営指標の要約だけで作る形式は、要約に換算差額などの行がないため、換算差額がある年はCFの式が合わない。
    # 原本で直せる誤りではないため、式の行を読む形式だけを照合する
    def reads_cash_flow_adjustments?(format)
      codes = Ingestion::Mappings.for(format)&.item_codes || []
      codes.intersect?(FinancialStatements::CashFlowVerification::ADJUSTMENTS)
    end
    private_class_method :missing_assets?, :revenue_mismatch, :chart_mismatch, :reads_cash_flow_adjustments?
  end
end
