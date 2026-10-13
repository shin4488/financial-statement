module FinancialStatements
  # 金額と、その入力から伝播した丸め誤差上限。精度が不明なら誤差を推測しない。
  class Amounts < Hash
    # store で端数を省いたことを、精度が不明な端数（nil）と区別する
    ROUNDING_ERROR_OMITTED = Object.new.freeze
    private_constant :ROUNDING_ERROR_OMITTED

    attr_reader :rounding_errors

    def initialize
      super
      @rounding_errors = {}
    end

    # 金額と端数の上限を組で書く。端数を省くと、Hashのstoreと同じく金額だけを書く
    def store(code, amount, rounding_error = ROUNDING_ERROR_OMITTED)
      result = super(code, amount)
      @rounding_errors[code] = rounding_error unless rounding_error.equal?(ROUNDING_ERROR_OMITTED)
      result
    end

    # 端数を比べず、金額だけを比べる
    def same_values?(other) = to_h == other.to_h

    # 複製は端数の表も別に持ち、複製への書き込みが元の端数を変えないようにする
    def initialize_copy(other)
      super
      @rounding_errors = other.rounding_errors.dup
    end
  end
end
