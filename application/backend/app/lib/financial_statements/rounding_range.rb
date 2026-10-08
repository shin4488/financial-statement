module FinancialStatements
  # 有報の金額は表示単位未満を四捨五入または切り捨てて開示されるため、合計行と内訳から
  # 計算した値は、計算に使った金額それぞれの端数の合計未満だけずれ得る。
  # 金額が一致するかは、取込でもグラフ作成でも、すべてこの範囲で判定する。
  module RoundingRange
    # difference: 照合する式の左辺と右辺の差。rounding_errors: 式に使ったすべての金額の端数の上限。
    # 差が0なら精度によらず一致とする。差があるときは、精度の分からない金額を含むと範囲を決められないため一致としない
    def self.within?(difference, rounding_errors)
      return true if difference.zero?
      rounding_errors.none?(&:nil?) && difference.abs < rounding_errors.sum
    end
  end
end
