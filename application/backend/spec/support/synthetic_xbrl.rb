# 合成XBRL: EDINETに接続せず、取込パイプライン全体（パース → DEI → 形式判定 → 抽出 → 保存）を
# 公開APIから検証するための最小の有報XBRL文字列を組み立てる。
# 実XBRLフィクスチャ（spec/fixtures/xbrl・git管理外）と違いCIでも常に実行できる
module SyntheticXbrl
  # 名前空間URIは Xbrl::Document::NS の判定パターンに一致させる（実タクソノミと同じURI構造）
  NS_URIS = {
    "jpdei_cor" => "http://disclosure.edinet-fsa.go.jp/taxonomy/jpdei/2013-08-31/jpdei_cor",
    "jppfs_cor" => "http://disclosure.edinet-fsa.go.jp/taxonomy/jppfs/2025-11-01/jppfs_cor",
    "jpigp_cor" => "http://disclosure.edinet-fsa.go.jp/taxonomy/jpigp/2025-11-01/jpigp_cor",
    "jpcrp_cor" => "http://disclosure.edinet-fsa.go.jp/taxonomy/jpcrp/2025-11-01/jpcrp_cor"
  }.freeze

  DEI_TAGS = {
    edinet_code: "jpdei_cor:EDINETCodeDEI",
    stock_code: "jpdei_cor:SecurityCodeDEI",
    name_ja: "jpdei_cor:FilerNameInJapaneseDEI",
    accounting_standard: "jpdei_cor:AccountingStandardsDEI",
    has_consolidated: "jpdei_cor:WhetherConsolidatedFinancialStatementsArePreparedDEI",
    fiscal_year_start_date: "jpdei_cor:CurrentFiscalYearStartDateDEI",
    fiscal_year_end_date: "jpdei_cor:CurrentFiscalYearEndDateDEI",
    filing_date: "jpcrp_cor:FilingDateCoverPage",
    consolidated_industry_code:
      "jpdei_cor:IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI",
    non_consolidated_industry_code:
      "jpdei_cor:IndustryCodeWhenFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI"
  }.freeze

  DEI_DEFAULTS = {
    edinet_code: "E00001",
    stock_code: "45020",
    name_ja: "テスト株式会社",
    accounting_standard: "Japan GAAP",
    has_consolidated: "false",
    fiscal_year_start_date: "2025-04-01",
    fiscal_year_end_date: "2026-03-31",
    filing_date: "2026-06-20"
  }.freeze

  # dei:   DEI_DEFAULTS を上書きするハッシュ（値nilでそのタグ自体を出さない）
  # facts: { ["jppfs_cor:Assets", "CurrentYearInstant_NonConsolidatedMember"] => 100, ... }
  def synthetic_xbrl_xml(dei: {}, facts: {})
    dei_values = DEI_DEFAULTS.merge(dei)
    elements = dei_values.filter_map do |key, value|
      fact_element(DEI_TAGS.fetch(key), "FilingDateInstant", value) unless value.nil?
    end
    elements += facts.map { |(qname, context), value| fact_element(qname, context, value) }
    ns_declarations = NS_URIS.map { |prefix, uri| %(xmlns:#{prefix}="#{uri}") }.join(" ")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <xbrli:xbrl xmlns:xbrli="http://www.xbrl.org/2003/instance" #{ns_declarations}>
      #{elements.join("\n")}
      </xbrli:xbrl>
    XML
  end

  def synthetic_xbrl_document(dei: {}, facts: {})
    file = Tempfile.new([ "synthetic", ".xbrl" ])
    file.write(synthetic_xbrl_xml(dei: dei, facts: facts))
    file.close
    Xbrl::Document.load(file.path)
  ensure
    file&.unlink
  end

  private
    def fact_element(qname, context, value)
      %(  <#{qname} contextRef="#{context}">#{ERB::Util.html_escape(value)}</#{qname}>)
    end
end

RSpec.configure { |config| config.include SyntheticXbrl }
