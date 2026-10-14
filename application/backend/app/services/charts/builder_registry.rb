module Charts
  # presentation_format → Builderの対応表。新形式はBS表・PL表に1行ずつ + Builderクラスの追加で対応する
  # （BS側だけ足すとPLが説明文になるだけで例外にはならないため、両方揃っているかはspecで検証している）
  module BuilderRegistry
    BS = {
      FinancialStatements::Formats::JGAAP_GENERAL   => Builders::BsJgaapGeneral,
      FinancialStatements::Formats::JGAAP_BANK      => Builders::BsJgaapBank,
      FinancialStatements::Formats::JGAAP_INSURANCE => Builders::BsJgaapInsurance,
      FinancialStatements::Formats::IFRS_CLASSIFIED => Builders::BsIfrsClassified,
      FinancialStatements::Formats::IFRS_LIQUIDITY  => Builders::BsIfrsLiquidity,
      FinancialStatements::Formats::IFRS_SUMMARY    => Builders::BsIfrsSummary,
      FinancialStatements::Formats::USGAAP_SUMMARY  => Builders::BsUsgaapSummary
    }.freeze
    PL = {
      FinancialStatements::Formats::JGAAP_GENERAL   => Builders::PlJgaapGeneral,
      # 銀行・保険のPLはどちらも 経常収益−経常費用=経常利益 の骨格のため共通Builderを使う
      FinancialStatements::Formats::JGAAP_BANK      => Builders::PlJgaapFinancialInstitution,
      FinancialStatements::Formats::JGAAP_INSURANCE => Builders::PlJgaapFinancialInstitution,
      # IFRSのPLはBSの様式（流動/非流動 or 流動性配列）に依存しないため共通Builderを使う
      FinancialStatements::Formats::IFRS_CLASSIFIED => Builders::PlIfrs,
      FinancialStatements::Formats::IFRS_LIQUIDITY  => Builders::PlIfrs,
      # 詳細タグなしでも経営指標サマリの収益・税引前利益で同じ骨格を描けるため共用する
      FinancialStatements::Formats::IFRS_SUMMARY    => Builders::PlIfrs,
      FinancialStatements::Formats::USGAAP_SUMMARY  => Builders::PlUsgaapSummary
    }.freeze
    UNSUPPORTED_NOTE = "この会計基準・業種の財務諸表は表示に対応していません。".freeze

    # StatementData を受ける。items_hash・presentation_format・fiscal_year_end_date を持つ値（ARモデルなど）も受け、その3つだけを読む
    def self.build_all(statement)
      items = statement.is_a?(FinancialStatements::StatementData) ? statement.amounts : statement.items_hash
      format = statement.presentation_format
      date = statement.fiscal_year_end_date
      {
        balance_sheet: BS[format]&.new(items, fiscal_year_end_date: date)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        profit_loss:   PL[format]&.new(items, fiscal_year_end_date: date)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        cash_flow:     Builders::CashFlow.new(items).build
      }
    end
  end
end
