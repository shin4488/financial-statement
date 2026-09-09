# 百万円・千円に縮小した開示値のテストでは、その単位での丸め精度も明示する。
module FinancialAmounts
  def rounded_amounts(values, unit: 1)
    FinancialStatements::Amounts.new.tap do |amounts|
      amounts.merge!(values)
      values.each_key { |code| amounts.rounding_errors[code] = unit.to_d }
    end
  end
end

RSpec.configure { |config| config.include FinancialAmounts }
