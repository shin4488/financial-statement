module UseCases
  # 1有報の取込の手順。原本の取得 → 対象確認 → 抽出 → 保存 → 点検の順序と、トランザクションの範囲と、Sentryへの通知を持つ。
  # 部品（対象確認・抽出・保存・点検）は結果を値で返し、通知はここから送る
  class IngestReport
    def initialize(client: Edinet::Client.new,
                   dei_extractor: Ingestion::DeiExtractor.new,
                   detector: Ingestion::FormatDetector.new)
      @client, @dei_extractor, @detector = client, dei_extractor, detector
      @extractor = Ingestion::StatementExtractor.new
      @writer = Disclosure::ReportWriter.new
    end

    # 財務諸表がない書類（訂正のみ等）は何もしない。
    # expected_sec_code: EDINETの書類一覧API（金融庁側メタデータ）のsecCode。
    # docID指定のrakeタスク経由では取得できないためnil可（突合をスキップ）
    def call(doc_id:, work_dir:, expected_sec_code: nil)
      xbrl_path = @client.download_xbrl(doc_id: doc_id, work_dir: work_dir)
      return if xbrl_path.nil?

      xbrl = Xbrl::Document.load(xbrl_path)
      dei = @dei_extractor.extract(xbrl)
      verdict = Ingestion::DocumentScreening.check(
        dei, doc_id: doc_id, expected_sec_code: expected_sec_code,
        known_report: -> { Disclosure::Report.includes(:company).find_by(edinet_document_id: doc_id) })
      case verdict.action
      when :exclude_fund
        @writer.exclude_from_listing(doc_id)
        return
      when :stop
        notify(IngestionNotices.build(verdict.notice_kind, **verdict.notice_values)) if verdict.notice_kind
        return
      end

      period_xbrl = xbrl.for_reporting_period(start_date: dei.fiscal_year_start_date, end_date: dei.fiscal_year_end_date)
      statements = @extractor.extract(period_xbrl, dei, detector: @detector)
      # トランザクション境界は「1有報」: 途中失敗で企業だけ出来て財務諸表がない、等の
      # 中途半端な状態を残さない。有報間は独立（1件の失敗が他社に波及しない）。
      # 通知は区分ごとの保存の直後に、トランザクションの中で送る。保存の後にまとめて送ると、
      # 保存が失敗して巻き戻ったときに通知の有無が変わるため
      ActiveRecord::Base.transaction do
        @writer.save(doc_id, dei, verdict.stock_code, statements) do |event, statement_data, financial_statement|
          if event == :skipped
            notify(IngestionNotices.build(:skip_empty_extraction, doc_id: doc_id, consolidation_type: statement_data.consolidation_type))
          else
            StatementInspection.notices(statement_data, primary: financial_statement.is_primary, doc_id: doc_id)
                               .each { |notice| notify(notice) }
          end
        end
      end
    ensure
      FileUtils.rm_f(xbrl_path) if xbrl_path
    end

    private
      def notify(notice) = Sentry.capture_message(notice.message, **notice.options)
  end
end
