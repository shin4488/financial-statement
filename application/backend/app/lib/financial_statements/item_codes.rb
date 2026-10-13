module FinancialStatements
  # 財務諸表ごとの科目コード。科目は ItemCatalog に定義し、ここではカタログの並びのまま財務諸表ごとに分ける
  module ItemCodes
    BS = ItemCatalog::ALL.select { |code| code.start_with?("bs.") }.freeze
    PL = ItemCatalog::ALL.select { |code| code.start_with?("pl.") }.freeze
    CF = ItemCatalog::ALL.select { |code| code.start_with?("cf.") }.freeze

    ALL = ItemCatalog::ALL
  end
end
