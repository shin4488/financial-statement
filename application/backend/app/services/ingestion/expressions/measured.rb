module Ingestion
  module Expressions
    # 取得式の評価結果。金額と、その入力から伝播した丸め誤差の上限（精度が不明なら nil）
    Measured = Data.define(:amount, :rounding_error)
  end
end
