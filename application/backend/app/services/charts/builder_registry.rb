module Charts
  # presentation_format → Builderの対応表。新形式の追加はここに1行 + Builderクラス追加で完結する
  module BuilderRegistry
    BS = {
      "jgaap_general"   => Builders::BsJgaapGeneral,
      "jgaap_bank"      => Builders::BsJgaapBank,
      "jgaap_insurance" => Builders::BsJgaapInsurance,
      "ifrs_classified" => Builders::BsIfrsClassified,
      "ifrs_liquidity"  => Builders::BsIfrsLiquidity
    }.freeze
    PL = {
      "jgaap_general"   => Builders::PlJgaapGeneral,
      # 銀行・保険のPLはどちらも 経常収益−経常費用=経常利益 の骨格のため共通Builderを使う
      "jgaap_bank"      => Builders::PlJgaapFinancialInstitution,
      "jgaap_insurance" => Builders::PlJgaapFinancialInstitution,
      # IFRSのPLはBSの様式（流動/非流動 or 流動性配列）に依存しないため共通Builderを使う
      "ifrs_classified" => Builders::PlIfrs,
      "ifrs_liquidity"  => Builders::PlIfrs
    }.freeze
    UNSUPPORTED_NOTE = "この会計基準・業種の財務諸表は表示に対応していません。".freeze

    def self.build_all(financial_statement)
      items = financial_statement.items_hash
      format = financial_statement.presentation_format
      {
        balance_sheet: BS[format]&.new(items)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        profit_loss:   PL[format]&.new(items)&.build || Charts::StackChart.unrenderable(UNSUPPORTED_NOTE),
        cash_flow:     Builders::CashFlow.new(items).build
      }
    end
  end
end
