module Ingestion
  # DEI（企業情報・会計期間・会計基準・業種コード）の抽出
  class DeiExtractor
    FILING = "FilingDateInstant".freeze

    Result = Struct.new(
      :edinet_code, :stock_code, :name_ja, :name_en,
      :accounting_standard, :has_consolidated,
      :fiscal_year_start_date, :fiscal_year_end_date, :filing_date,
      :consolidated_industry_code, :non_consolidated_industry_code,
      keyword_init: true
    )

    STANDARD_MAP = { "Japan GAAP" => "japan_gaap", "US GAAP" => "us_gaap", "IFRS" => "ifrs" }.freeze

    def extract(xbrl)
      Result.new(
        edinet_code: xbrl.text("jpdei_cor:EDINETCodeDEI", FILING),
        stock_code: xbrl.text("jpdei_cor:SecurityCodeDEI", FILING), # 5桁（例: "45020"）のまま保存。4桁化は表示層の責務
        # 企業名は表紙（CoverPage）を優先し、表紙タグがない書類はDEIの提出者名にフォールバック
        name_ja: normalize_width(xbrl.text("jpcrp_cor:CompanyNameCoverPage", FILING) ||
                                 xbrl.text("jpdei_cor:FilerNameInJapaneseDEI", FILING)),
        name_en: normalize_width(xbrl.text("jpcrp_cor:CompanyNameInEnglishCoverPage", FILING) ||
                                 xbrl.text("jpdei_cor:FilerNameInEnglishDEI", FILING)),
        accounting_standard: STANDARD_MAP.fetch(xbrl.text("jpdei_cor:AccountingStandardsDEI", FILING), nil),
        # xs:booleanの真は "true" と "1" の2表記が正当なため両方受ける
        has_consolidated: %w[true 1].include?(xbrl.text("jpdei_cor:WhetherConsolidatedFinancialStatementsArePreparedDEI", FILING)),
        fiscal_year_start_date: xbrl.text("jpdei_cor:CurrentFiscalYearStartDateDEI", FILING),
        fiscal_year_end_date: xbrl.text("jpdei_cor:CurrentFiscalYearEndDateDEI", FILING),
        filing_date: xbrl.text("jpcrp_cor:FilingDateCoverPage", FILING),
        consolidated_industry_code:
          xbrl.text("jpdei_cor:IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI", FILING),
        non_consolidated_industry_code:
          xbrl.text("jpdei_cor:IndustryCodeWhenFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI", FILING),
      )
    end

    private
      # 全角英数字・スペース・アンパサンドを半角へ正規化する。
      # 意図: EDINET上の企業名は全角英数（例: 「ＡＢＣ株式会社」）で登録されており、
      # そのままだと証券コード検索やUI表示・照合で半角と混在して扱いにくいため
      def normalize_width(text)
        text&.tr("０-９ａ-ｚＡ-Ｚ　＆", "0-9a-zA-Z &")
      end
  end
end
