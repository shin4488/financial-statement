module FinancialStatements
  # 金額と、その入力から伝播した丸め誤差上限。精度が不明なら誤差を推測しない。
  # 科目ごとの金額の表と端数の表を持つ。書くときは store を使い、StatementData にするときに凍結する。
  # rounding_errors は端数の表そのものを返し、凍結するまでは書けるが、直接書かない
  class Amounts
    include Enumerable

    attr_reader :rounding_errors

    def initialize
      @amounts = {}
      @rounding_errors = {}
    end

    # 金額と端数の上限を組で書き、金額を返す
    def store(code, amount, rounding_error)
      @amounts[code] = amount
      @rounding_errors[code] = rounding_error
      amount
    end

    def [](code) = @amounts[code]
    def key?(code) = @amounts.key?(code)
    def values_at(*codes) = @amounts.values_at(*codes)
    def rounding_error(code) = @rounding_errors[code]
    def codes = @amounts.keys
    def empty? = @amounts.empty?

    # 科目コードと金額の組を順に渡す
    def each(&block)
      return enum_for(:each) { @amounts.size } unless block
      @amounts.each(&block)
      self
    end

    # 一部の科目の金額だけの普通のHash（Sentryのextraなどに渡す形）
    def slice(*codes) = @amounts.slice(*codes)
    def except(*codes) = @amounts.except(*codes)

    # 端数を比べず、金額だけを比べる
    def same_values?(other) = @amounts == other.amounts

    # 金額と端数の両方を比べる。StatementData（Data）の == は属性の == を、eql? と hash（Hashのキー）は属性の eql? と hash を使うため、
    # 3つとも同じ2つの表から求める
    def ==(other) = other.is_a?(Amounts) && same_values?(other) && @rounding_errors == other.rounding_errors
    def eql?(other) = other.is_a?(Amounts) && @amounts.eql?(other.amounts) && @rounding_errors.eql?(other.rounding_errors)
    def hash = [ @amounts, @rounding_errors ].hash

    # 表を指す本体だけでなく、2つの表も凍結する
    def freeze
      @amounts.freeze
      @rounding_errors.freeze
      super
    end

    # 複製は2つの表を別に持ち、複製への書き込みが元を変えないようにする
    def initialize_copy(other)
      super
      @amounts = other.amounts.dup
      @rounding_errors = other.rounding_errors.dup
    end

    # clone は凍結した状態も写すが、#freeze を呼ばないため、複製した表もここで凍結する
    def initialize_clone(other, freeze: nil)
      super
      self.freeze if freeze || (freeze.nil? && other.frozen?)
    end

    protected
      attr_reader :amounts
  end
end
