module Ingestion
  # 形式によらない抽出器。形式ごとの違いは対応表として受け取り、科目をすべて評価してから補正ルールを一覧の順に適用する
  class StatementExtractor
    # mapping は、評価する科目（code・period・expression）の一覧 items と、科目コードから取得式を引く expression(code)、
    # 差し替えのときだけ使う候補を引く replacements(code) を持つ。
    # source・consolidation は取得式に渡す値（Ingestion::Expressions）
    def self.amounts(mapping, source:, consolidation:)
      amounts = FinancialStatements::Amounts.new
      # 取れなかった科目はキーごと入れない（「開示なし」をnilや0でなくキーの不存在で表す。DBの「行の不存在=開示なし」と対になる規約）
      mapping.items.each do |item|
        measured = item.expression.evaluate(source, period: item.period, consolidation: consolidation)
        amounts.store(item.code, measured.amount, measured.rounding_error) if measured
      end
      Adjustments::ALL.each { |adjustment| adjustment.apply(amounts, mapping: mapping, source: source, consolidation: consolidation) }
      amounts
    end

    # 有報の区分（連結を作成していれば連結、と単体）ごとに、形式を判定して科目と公表ROEを取る。
    # period は事業年度で引くXBRL（Xbrl::ReportingPeriod）、detector は形式判定（Ingestion::FormatDetector）
    def extract(period, dei, detector:)
      sections = []
      if dei.has_consolidated
        sections << [ :consolidated, Extractors::Base::CONSOLIDATED, dei.accounting_standard, dei.consolidated_industry_code ]
      end
      # 単体は日本基準固定: IFRS・US GAAP適用企業でも単体財務諸表は日本基準（jppfs）で
      # タグ付けされるため
      sections << [ :non_consolidated, Extractors::Base::NON_CONSOLIDATED, "japan_gaap", dei.non_consolidated_industry_code ]

      sections.map do |type, suffix, standard, industry|
        format = detector.detect(period, accounting_standard: standard, industry_code: industry, consolidation: suffix)
        consolidation = Xbrl::ReportingPeriod::CONSOLIDATIONS[suffix]
        mapping = Mappings.for(format)
        amounts = mapping ? self.class.amounts(mapping, source: period, consolidation: consolidation) : FinancialStatements::Amounts.new
        # 決算日は持たない。点検はグラフに決算日を渡さず、保存はDEIの会計期間を使う
        FinancialStatements::StatementData.new(
          consolidation_type: type, accounting_standard: standard, presentation_format: format, amounts: amounts,
          disclosed_roe: Mappings::DisclosedRoe.amount(period, accounting_standard: standard, consolidation: consolidation),
          fiscal_year_end_date: nil)
      end
    end
  end
end
