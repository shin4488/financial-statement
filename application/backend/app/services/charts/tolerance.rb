module Charts
  # 描く前に金額どうしを突き合わせるときの判定。描くかどうかは許容差、照合の警告は端数の範囲で決める
  module Tolerance
    # 合計と突き合わせるときの許容乖離1割（貸借合計・固定資産の内訳合計など）。
    # 超えたら「未対応の様式か取込不良」とみなして描画しない。
    # 誤ったグラフを出すより出さない方がよい、という安全側の判断
    TOLERANCE = 0.1

    # base（乖離率の分母になる側）に対して value が TOLERANCE 以内か
    def self.within?(base, value)
      return false if base.zero?
      (value - base).abs <= base * TOLERANCE
    end

    # 保存した科目どうしの式が端数の範囲で成り立つか。differenceは式の左辺と右辺の差、codesは式に使った科目。
    # 端数を持たない入力（精度の分からない科目）では、差が0のときだけ成り立つとみなす
    def self.balanced?(items, difference, codes)
      errors = items.respond_to?(:rounding_errors) ? items.rounding_errors.values_at(*codes) : codes.map { nil }
      FinancialStatements::RoundingRange.within?(difference, errors)
    end
  end
end
