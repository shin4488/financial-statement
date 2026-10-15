module Ingestion
  # 対象確認。DEIから、取り込むか・照合と保存に使う証券コード・送る通知を判定する。
  # DBも通知も使わず、既存書類は渡された処理（known_report）で引く
  module DocumentScreening
    # action は :proceed（取り込む）・:exclude_fund（ファンドの書類を表示対象から外して終える）・:stop（取り込まずに終える）。
    # notice_kind・notice_values は送る通知の種類と値（UseCases::IngestionNotices）で、送らないときは nil と空のHash
    Verdict = Data.define(:action, :stock_code, :notice_kind, :notice_values)

    module_function

    # expected_sec_code: EDINETの書類一覧API（金融庁側メタデータ）のsecCode。docID指定の取込では取得できないためnil可（突合をスキップ）。
    # known_report: 同じ書類IDの既存書類（企業を先読みしたもの）を返す処理。DEIの証券コードが空のときだけ呼ぶ
    def check(dei, doc_id:, expected_sec_code:, known_report:)
      # docIDを直接指定した取込でも対象外を除く。ファンドの提出者は上場企業の場合がある。
      # 企業マスタや既存有報を触る前に、書類自身の証券コードとFundCodeDEIを確認する。
      return verdict(:exclude_fund, nil) if dei.fund_code.present?

      stock_code = dei.stock_code
      if stock_code.blank?
        report = known_report.call
        return verdict(:stop, nil) unless known_report?(report, dei)
        # 上場廃止後は企業マスタも空欄になり得る。証券コードを推測せず、照合した既存書類として取り込む。
        stock_code = report.company.stock_code
      end
      if dei.accounting_standard.nil?
        # 会計基準不明のまま取り込むと形式判定できないためスキップ。ただし黙殺すると
        # 「特定企業だけデータが無い」原因を追えなくなるため警告だけ残す
        return verdict(:stop, stock_code, :accounting_standard_unknown, doc_id: doc_id)
      end
      # 文書内DEIは提出者が書いた値のため、企業マスタのキーとして信頼する前に検証する。
      # 権威ある一覧メタデータと食い違う書類（なりすまし・提出ミス）は他社レコードを
      # 上書きし得るため取り込まない
      unless dei.edinet_code.to_s.match?(/\A[A-Z]\d{5}\z/)
        return verdict(:stop, stock_code, :invalid_edinet_code, doc_id: doc_id, edinet_code: dei.edinet_code)
      end
      if expected_sec_code && stock_code != expected_sec_code
        return verdict(:stop, stock_code, :sec_code_mismatch,
                       doc_id: doc_id, expected_sec_code: expected_sec_code, stock_code: stock_code)
      end
      verdict(:proceed, stock_code)
    end

    # 上場前・上場廃止後の有報は証券コードが空でも財務数値を含む。
    # 新規の紐付けは行わず、既存書類・企業・会計期間がすべて一致する再取込だけ認める。
    def known_report?(report, dei)
      return false unless report && report.company.edinet_code == dei.edinet_code
      report.fiscal_year_start_date.to_s == dei.fiscal_year_start_date &&
        report.fiscal_year_end_date.to_s == dei.fiscal_year_end_date
    end

    def verdict(action, stock_code, notice_kind = nil, **notice_values)
      Verdict.new(action: action, stock_code: stock_code, notice_kind: notice_kind, notice_values: notice_values)
    end
    private_class_method :known_report?, :verdict
  end
end
