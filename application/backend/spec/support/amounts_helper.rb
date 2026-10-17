# 金額の表（FinancialStatements::Amounts）を作る補助
module AmountsHelper
  # 端数の上限がどれも nil（精度の分からない金額）の表。照合では、差が0のときだけ式が成り立つ
  def amounts_of_unknown_precision(values)
    FinancialStatements::Amounts.new.tap do |amounts|
      values.each { |code, amount| amounts.store(code, amount, nil) }
    end
  end
end

RSpec.configure { |config| config.include AmountsHelper }
