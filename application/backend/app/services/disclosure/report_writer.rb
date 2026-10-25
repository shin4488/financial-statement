module Disclosure
  # 取り込んだ有報の保存。通知は送らず、区分ごとに何をしたかをブロックに渡す
  class ReportWriter
    # 1有報分の書き込み。途中で失敗したときに1有報分をまとめて巻き戻せるよう、呼び出し側のトランザクションの中で呼ぶ。
    # statements: [FinancialStatements::StatementData]。stock_code は企業マスタに保存する証券コード（対象確認で補ったときはその値）。
    # 区分ごとに、保存したら :saved、当期の科目がなく既存を残したら :skipped を、その区分の値と財務諸表（ARモデル）とともに、
    # その区分を書いた直後にブロックへ渡す
    def save(doc_id, dei, stock_code, statements)
      company = upsert_company(dei, stock_code)
      report = upsert_report(company, doc_id, dei)
      # 今回の取込に現れない区分の行は削除する。連結廃止
      # （has_consolidatedがtrue→false）の再取込で旧・連結行の is_primary: true が
      # 残ると、一覧検索のJOINが同じ有報を2回返してしまうため
      report.financial_statements
            .where.not(consolidation_type: statements.map(&:consolidation_type))
            .destroy_all
      # 主とする区分が替わる再取込（連結を含む訂正有報など）では、新しい主を立てる前に旧い主を外す。
      # 区分ごとに更新する途中で主が2つになり、1有報1主の一意制約に反するため
      primary_type = primary_consolidation_type(statements, dei)
      report.financial_statements.where(is_primary: true)
            .where.not(consolidation_type: primary_type)
            .update_all(is_primary: false)
      statements.each do |statement_data|
        financial_statement, event = upsert_statement(report, statement_data,
                                                      primary: statement_data.consolidation_type == primary_type)
        yield event, statement_data, financial_statement
      end
    end

    # 過去に誤って企業の財務として保存したファンドも表示対象から外す。
    # 科目と書類は監査・復旧のため残す。
    def exclude_from_listing(doc_id)
      Disclosure::Report.find_by(edinet_document_id: doc_id)&.financial_statements&.each do |statement|
        statement.update!(is_primary: false) if statement.is_primary?
      end
    end

    private
      # find_or_initialize + update! で作成/更新を同型に扱う（訂正有報・バックフィル
      # 再実行の冪等性）。自然キーはedinet_code（証券コードは変わり得るがEDINETコードは不変）
      def upsert_company(dei, stock_code)
        company = Disclosure::Company.find_or_initialize_by(edinet_code: dei.edinet_code)
        # 企業マスタの名前・証券コードは「最新期の有報」からのみ更新する。
        # 過去年度をバックフィルしたとき、社名変更前の古い名前でマスタが
        # 上書きされるのを防ぐため（当時の名前はreports側に保存する）
        if latest_fiscal_year?(company, dei)
          company.update!(stock_code: stock_code, name_ja: dei.name_ja, name_en: dei.name_en)
        end
        company
      end

      # Reportの自然キーは (企業, 会計期間)。edinet_document_id ではない点に注意:
      # 訂正有報は別docIDで届くが「同じ期の報告書の上書き」として扱いたいため
      def upsert_report(company, doc_id, dei)
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
        report
      end

      # 財務諸表（ARモデル）と、:saved か :skipped を返す
      def upsert_statement(report, statement_data, primary:)
        fs = Disclosure::FinancialStatement.find_or_initialize_by(
          report: report, consolidation_type: statement_data.consolidation_type)
        # 当期科目が取れない再取込は既存行を保持してスキップする。
        # 財務factを含まない訂正有報（訂正箇所のみのXBRL）で、正しい科目と
        # 形式判定を空で上書きしないためのガード。空のまま新規作成するのは
        # 正常系（unsupported形式など）なのでスキップしない
        # 期首残高だけが取れる書類も、当期の財務諸表を置き換える根拠にはしない。
        current_items = statement_data.amounts.except(*FinancialStatements::ItemCatalog.opening_codes)
        return [ fs, :skipped ] if current_items.empty? && fs.persisted? && fs.items.exists?

        fs.update!(
          accounting_standard: statement_data.accounting_standard,
          presentation_format: statement_data.presentation_format,
          disclosed_roe: statement_data.disclosed_roe,
          disclosed_roe_checked_at: Time.current,
          is_primary: primary)
        replace_items(fs, statement_data.amounts)
        [ fs, :saved ]
      end

      # 科目は総入れ替え（delete→insert）。upsertにしない理由:
      # 「行の存在=開示あり」の規約のため、訂正で開示されなくなった科目は
      # 消えてもらう必要がある。upsertでは残留してしまう
      def replace_items(fs, items)
        fs.items.delete_all
        rows = items.map { |code, amount|
          { financial_statement_id: fs.id, item_code: code, amount: amount,
            rounding_error: items.rounding_error(code),
            created_at: Time.current, updated_at: Time.current } }
        # insert_all!はモデルのバリデーションを通らないため、item_codeの正当性は
        # 対応表の科目が科目カタログ（ItemCatalog::ALL）にあること（対応表の読込時の確認と対応表の検査のspec）で担保する
        Disclosure::FinancialStatementItem.insert_all!(rows) if rows.any?
      end

      # is_primary = 一覧表示・検索の対象。投資判断では連結が重要のため連結を優先し、
      # 連結を作成しない企業のみ単体を主とする。主の区分の値だけでカードのBS・PL・CF・指標を作り、連結と単体の値を組み合わせない。
      #
      # 例外は、連結財務諸表が貸借対照表だけの有報。連結財務諸表を作る会社は、ふつう連結の貸借対照表・損益計算書・
      # キャッシュ・フロー計算書をそろえて作り、単体のキャッシュ・フロー計算書は作らない。ただし連結初年度で、その期の子会社の
      # 損益を連結しない会社（子会社のみなし取得日を期末にした・子会社の決算日がまだ来ていないなど）は、子会社の損益は取り込まず
      # 資産・負債だけを取り込んだ連結貸借対照表を作り、連結の損益計算書・キャッシュ・フロー計算書を作らない。その期の損益・CFは、
      # 単体の損益計算書と、連結のものがないため作る単体のキャッシュ・フロー計算書で開示する。連結を主にするとPL・CF・指標が欠け、
      # 会社自身も損益に使う単体の数値でカードがそろうため、単体を主にする。
      #
      # 取れた科目で区分を選ぶ（単体の貸借対照表の有無は見ない）:
      # - 連結に資産合計があり、当期の損益・CFの科目がなく、単体に当期の損益かCFの科目がある → 単体（上の例外）
      # - 連結に資産合計があり、当期の損益・CFの科目がなく、単体にも当期の損益・CFの科目がない → 連結
      # - 連結に当期の損益かCFの科目がある（損益だけ、またはCFだけが欠ける場合を含む） → 連結
      # - 連結に資産合計がない（損益・CFはある、または何も取れない未対応の形式） → 連結
      #
      # 連結の損益だけ・CFだけ・資産合計だけが欠ける有報は単体にしない。会社は連結の三表をそろえて開示していて、欠けるのは
      # 企業独自のタグなどで取込が値を取れないときだから。単体に替えると、子会社を含まない別の範囲の値を見せることになる。
      # 欠けた表は説明文にし、ほかの表と指標は連結の値のまま出す
      def primary_consolidation_type(statements, dei)
        return :non_consolidated unless dei.has_consolidated

        consolidated, non_consolidated = %i[consolidated non_consolidated].map do |type|
          statements.find { |statement_data| statement_data.consolidation_type == type }
        end
        balance_sheet_only?(consolidated) && flows?(non_consolidated) ? :non_consolidated : :consolidated
      end

      # 貸借対照表は、どの形式でも保存する資産合計で有無を見る
      def balance_sheet_only?(statement_data)
        statement_data&.amounts&.key?("bs.assets") && !flows?(statement_data)
      end

      # 当期の損益・CFの科目（期間の科目）があるか。経営指標の要約から取る売上も数え、時点の科目の期首残・期末残は数えない
      def flows?(statement_data)
        statement_data && (statement_data.amounts.codes & FinancialStatements::ItemCatalog.duration_codes).any?
      end

      # この有報がその企業の最新会計期か（同じ期の再取込・訂正有報も最新扱い）。
      # 表示から外した書類（主たる財務諸表がない有報。企業の有報として誤って取り込んだファンドの書類など）は、
      # 企業自身の決算ではないため比べない。比べると、その会計期間の終わりが過ぎるまで企業マスタが更新されなくなる
      def latest_fiscal_year?(company, dei)
        return true if company.new_record?
        Disclosure::Report.where(company: company)
                          .where("fiscal_year_end_date > ?", dei.fiscal_year_end_date)
                          .joins(:primary_financial_statement)
                          .none?
      end
  end
end
