module Disclosure
  # 再取込タスク（rake ingestion:reingest_*）で取り直す有報のdocID。どれも提出日の順に返す
  module ReingestTargets
    module_function

    # ROE・ROA用の期首残高・自己資本が不足する、主の財務諸表（unsupported を除く）の有報
    def indicators
      required_codes = %w[bs.assets_begin bs.equity_attributable_to_owners bs.equity_attributable_to_owners_begin]
      complete_statement_ids = FinancialStatementItem
                                 .where(item_code: required_codes)
                                 .group(:financial_statement_id)
                                 .having("COUNT(DISTINCT item_code) = ?", required_codes.size)
                                 .select(:financial_statement_id)
      target_statements = FinancialStatement.where(is_primary: true)
                            .where.not(presentation_format: FinancialStatements::Formats::UNSUPPORTED)
                            .where.not(id: complete_statement_ids)
      doc_ids_of(target_statements)
    end

    # 企業公表ROEを確かめていない財務諸表を含む有報
    def disclosed_roe
      report_ids = FinancialStatement.where(disclosed_roe_checked_at: nil).select(:report_id)
      Report.where(id: report_ids).order(:filing_date).pluck(:edinet_document_id)
    end

    # ifrs_summary形式の追加前に取り込まれ、詳細タグの無い有報が ifrs_liquidity として保存されている有報。
    # 対象を「primaryなのに資産合計が無い」に絞るのは、正しく ifrs_liquidity と判定された有報を再取込せず
    # EDINETへのリクエストを最小にするため（移行完了後は対象0件になり、再実行しても何もしない）
    def ifrs_summary
      target_statements = FinancialStatement
                            .where(presentation_format: FinancialStatements::Formats::IFRS_LIQUIDITY, is_primary: true)
                            .where.not(id: FinancialStatementItem.where(item_code: "bs.assets").select(:financial_statement_id))
      doc_ids_of(target_statements)
    end

    # unsupported と判定した財務諸表を含む有報のうち、提出日が from..to（両端を含む）のもの。
    # 新しい形式（業種）に対応したあとに取り直す。対象を unsupported に絞るのは、全期間のバックフィルより
    # EDINETへのリクエストが桁違いに少なくて済むため
    def unsupported(from, to)
      report_ids = FinancialStatement.where(presentation_format: FinancialStatements::Formats::UNSUPPORTED).select(:report_id)
      Report.where(id: report_ids, filing_date: from..to).order(:filing_date).pluck(:edinet_document_id)
    end

    def doc_ids_of(statements)
      Report.where(id: statements.select(:report_id)).order(:filing_date).pluck(:edinet_document_id)
    end
    private_class_method :doc_ids_of
  end
end
