module Ingestion
  # 1有報の取込オーケストレーション + 永続化
  class ReportIngester
    def initialize(client: Edinet::Client.new,
                   dei_extractor: DeiExtractor.new,
                   detector: FormatDetector.new)
      @client, @dei_extractor, @detector = client, dei_extractor, detector
    end

    # 1有報の取込。財務諸表がない書類（訂正のみ等）は何もしない。
    # expected_sec_code: EDINETの書類一覧API（金融庁側メタデータ）のsecCode。
    # docID指定のrakeタスク経由では取得できないためnil可（突合をスキップ）
    def ingest(doc_id:, work_dir:, expected_sec_code: nil)
      xbrl_path = @client.download_xbrl(doc_id: doc_id, work_dir: work_dir)
      return if xbrl_path.nil?

      xbrl = Xbrl::Document.load(xbrl_path)
      dei = @dei_extractor.extract(xbrl)
      if dei.accounting_standard.nil?
        # 会計基準不明のまま取り込むと形式判定できないためスキップ。ただし黙殺すると
        # 「特定企業だけデータが無い」原因を追えなくなるため警告だけ残す
        Sentry.capture_message("accounting standard unknown: #{doc_id}", level: :warning)
        return
      end
      # 文書内DEIは提出者が書いた値のため、企業マスタのキーとして信頼する前に検証する。
      # 権威ある一覧メタデータと食い違う書類（なりすまし・提出ミス）は他社レコードを
      # 上書きし得るため取り込まない
      unless dei.edinet_code.to_s.match?(/\A[A-Z]\d{5}\z/)
        Sentry.capture_message("invalid edinet code in DEI: #{doc_id} (#{dei.edinet_code.inspect})", level: :error)
        return
      end
      if expected_sec_code && dei.stock_code.present? && dei.stock_code != expected_sec_code
        Sentry.capture_message(
          "sec code mismatch: #{doc_id} (list=#{expected_sec_code} dei=#{dei.stock_code})", level: :error)
        return
      end

      statements = build_statements(xbrl, dei)
      persist(doc_id, dei, statements)
    ensure
      FileUtils.rm_f(xbrl_path) if xbrl_path
    end

    private
      Extraction = Struct.new(:consolidation_type, :accounting_standard, :format, :items, keyword_init: true)

      def build_statements(xbrl, dei)
        specs = []
        if dei.has_consolidated
          specs << [ :consolidated, Extractors::Base::CONSOLIDATED,
                    dei.accounting_standard, dei.consolidated_industry_code ]
        end
        # 単体は日本基準固定: IFRS・US GAAP適用企業でも単体財務諸表は日本基準（jppfs）で
        # タグ付けされるため
        specs << [ :non_consolidated, Extractors::Base::NON_CONSOLIDATED,
                  "japan_gaap", dei.non_consolidated_industry_code ]

        specs.map do |type, suffix, standard, industry|
          format = @detector.detect(xbrl, accounting_standard: standard,
                                    industry_code: industry, consolidation: suffix)
          extractor_class = FormatRegistry.extractor_for(format)
          items = extractor_class ? extractor_class.new(xbrl, suffix).extract : {}
          Extraction.new(consolidation_type: type, accounting_standard: standard,
                         format: format, items: items)
        end
      end

      # トランザクション境界は「1有報」: 途中失敗で企業だけ出来て財務諸表がない、等の
      # 中途半端な状態を残さない。有報間は独立（1件の失敗が他社に波及しない）
      def persist(doc_id, dei, statements)
        ActiveRecord::Base.transaction do
          # find_or_initialize + update! で作成/更新を同型に扱う（訂正有報・バックフィル
          # 再実行の冪等性）。自然キーはedinet_code（証券コードは変わり得るがEDINETコードは不変）
          company = Disclosure::Company.find_or_initialize_by(edinet_code: dei.edinet_code)
          # 企業マスタの名前・証券コードは「最新期の有報」からのみ更新する。
          # 過去年度をバックフィルしたとき、社名変更前の古い名前でマスタが
          # 上書きされるのを防ぐため（当時の名前はreports側に保存する）
          if latest_fiscal_year?(company, dei)
            company.update!(stock_code: dei.stock_code, name_ja: dei.name_ja, name_en: dei.name_en)
          end

          # Reportの自然キーは (企業, 会計期間)。edinet_document_id ではない点に注意:
          # 訂正有報は別docIDで届くが「同じ期の報告書の上書き」として扱いたいため
          report = Disclosure::Report.find_or_initialize_by(
            company: company,
            fiscal_year_start_date: dei.fiscal_year_start_date,
            fiscal_year_end_date: dei.fiscal_year_end_date)
          report.update!(
            edinet_document_id: doc_id, filing_date: dei.filing_date,
            company_name_ja: dei.name_ja, company_name_en: dei.name_en,
            accounting_standard: dei.accounting_standard,
            has_consolidated_statement: dei.has_consolidated,
            consolidated_industry_code: dei.consolidated_industry_code,
            non_consolidated_industry_code: dei.non_consolidated_industry_code)

          # 今回の取込に現れない区分の行は削除する。連結廃止
          # （has_consolidatedがtrue→false）の再取込で旧・連結行の is_primary: true が
          # 残ると、一覧検索のJOINが同じ有報を2回返してしまうため
          report.financial_statements
                .where.not(consolidation_type: statements.map(&:consolidation_type))
                .destroy_all

          statements.each do |ext|
            fs = Disclosure::FinancialStatement.find_or_initialize_by(
              report: report, consolidation_type: ext.consolidation_type)
            # 科目が1つも取れない再取込は既存行を保持してスキップする。
            # 財務factを含まない訂正有報（訂正箇所のみのXBRL）で、正しい科目と
            # 形式判定を空で上書きしないためのガード。空のまま新規作成するのは
            # 正常系（unsupported形式など）なのでスキップしない
            if ext.items.empty? && fs.persisted? && fs.items.exists?
              Sentry.capture_message(
                "skip empty extraction for existing statement: #{doc_id} (#{ext.consolidation_type})",
                level: :warning)
              next
            end
            fs.update!(
              accounting_standard: ext.accounting_standard,
              presentation_format: ext.format,
              is_primary: primary?(ext, dei))
            # 科目は総入れ替え（delete→insert）。upsertにしない理由:
            # 「行の存在=開示あり」の規約のため、訂正で開示されなくなった科目は
            # 消えてもらう必要がある。upsertでは残留してしまう
            fs.items.delete_all
            rows = ext.items.map { |code, amount|
              { financial_statement_id: fs.id, item_code: code, amount: amount,
                created_at: Time.current, updated_at: Time.current } }
            # insert_all!はモデルのバリデーションを通らないため、item_codeの正当性は
            # Extractorのマッピング定数がItemCodes::ALLの範囲内であることをspecで担保する
            Disclosure::FinancialStatementItem.insert_all!(rows) if rows.any?

            # 主対象なのに資産合計すら取れないのは形式判定ミスの可能性が高い。
            # 取込自体は継続する（unsupported形式や科目欠落はエラーではないため）。
            # ifrs_summaryはBSを抽出しない形式のため対象外
            if fs.is_primary && !ext.items.key?("bs.assets") &&
               ![ FormatRegistry::UNSUPPORTED, FormatRegistry::IFRS_SUMMARY ].include?(ext.format)
              Sentry.capture_message(
                "primary statement missing bs.assets: #{doc_id} (#{ext.format})", level: :warning)
            end
          end
        end
      end

      # is_primary = 一覧表示・検索の対象。投資判断では連結が重要のため連結を優先し、
      # 連結を作成しない企業のみ単体を主とする
      def primary?(ext, dei)
        dei.has_consolidated ? ext.consolidation_type == :consolidated
                             : ext.consolidation_type == :non_consolidated
      end

      # この有報がその企業の最新会計期か（同じ期の再取込・訂正有報も最新扱い）
      def latest_fiscal_year?(company, dei)
        return true if company.new_record?
        Disclosure::Report.where(company: company)
                          .where("fiscal_year_end_date > ?", dei.fiscal_year_end_date)
                          .none?
      end
  end
end
