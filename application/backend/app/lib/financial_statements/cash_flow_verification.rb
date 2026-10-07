module FinancialStatements
  # キャッシュ・フロー計算書の「期首残＋営業CF＋投資CF＋財務CF＋換算差額など＝期末残」で、取り込んだ値を確かめる。
  # その年に財務や投資の活動がない会社は、その行を「－」（値のないタグ）にするか載せないため、科目が保存されない。
  # 行がない項目は、0とみなして式が端数の範囲で成り立つときだけ0として扱う（保存する値は変えない。行がない＝開示なしの決まりを保つ）。
  # 成り立たなければ、行がない項目は実際には0でない（企業拡張タグで開示しているなど）おそれがあるため、0にしない
  module CashFlowVerification
    # 0とみなせる項目。期末残は含めない。期末残までないCFは、CF計算書そのものがない（連結初年度で連結CFを作っていないなど）ため
    FLOWS = %w[cf.cash_begin cf.operating cf.investing cf.financing].freeze
    # 式に足す、グラフに描かない行。換算差額・新規連結・連結範囲の変更・合併による増減。行がなければ0
    ADJUSTMENTS = %w[cf.exchange_effect cf.new_consolidation cf.consolidation_change cf.merger].freeze
    CLOSING = "cf.cash_end".freeze

    # 期首残・営業CF・投資CF・財務CF・期末残（{科目コード => 金額}）。式が成り立てば、行がない項目を0にする。
    # 成り立たないか、期末残がなければ、行がない項目はnilのまま
    def self.amounts(items)
      values = (FLOWS + [ CLOSING ]).to_h { |code| [ code, items[code] ] }
      return values if values.values.none?(&:nil?) || !balanced?(items)
      values.transform_values { |amount| amount || 0 }
    end

    # 行がない項目を0とみなしても式が端数の範囲で成り立たないときの、式に使った金額。期末残がなければ照合できないためnil
    def self.mismatch(items)
      return if items[CLOSING].nil? || balanced?(items)
      (FLOWS + ADJUSTMENTS + [ CLOSING ]).to_h { |code| [ code, items[code] ] }.compact
    end

    def self.balanced?(items)
      return false if items[CLOSING].nil?
      codes = FLOWS + ADJUSTMENTS + [ CLOSING ]
      difference = items[CLOSING] - (FLOWS + ADJUSTMENTS).sum { |code| items[code] || 0 }
      # 行がない項目は0と開示されたものとして扱い、端数を持たない。行がある項目の精度が分からなければ、差が0のときだけ成り立つ
      errors = codes.map do |code|
        next 0 if items[code].nil?
        items.respond_to?(:rounding_errors) ? items.rounding_errors[code] : nil
      end
      RoundingRange.within?(difference, errors)
    end
    private_class_method :balanced?
  end
end
