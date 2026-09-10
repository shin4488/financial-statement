module FinancialStatements
  # 金額と、その入力から伝播した丸め誤差上限。精度が不明なら誤差を推測しない。
  class Amounts < Hash
    attr_reader :rounding_errors

    def initialize
      super
      @rounding_errors = {}
    end
  end
end
