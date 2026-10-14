module Charts
  # 積み上げ棒の項目（Segment）の作り方と、比率の求め方
  module Segments
    RATIO_PRECISION = 1 # %表示の小数桁数

    # Segmentの生成規約:
    #   amount       = 描画高さ。絶対値（rechartsに負を渡すと棒が逆向きに描かれるため）
    #   signed_amount= 実値。ツールチップ表示用。signed引数で明示指定がなければamountと同じ
    #   ratio        = signed基準で計算（損失なら負の%になり「-3.1%」と表示される）
    #   tooltip      = ツールチップ専用の表示名（未指定ならlabelが表示される）
    def self.segment(key, label, amount, role, base:, signed: nil, tooltip: nil)
      Segment.new(key: key, label: label, amount: amount.abs,
                  signed_amount: signed || amount, ratio: ratio(signed || amount, base),
                  color_role: role, tooltip_label: tooltip)
    end

    # 比率は%値（0-100）。truncate（切り捨て）を使う理由: 四捨五入だと内訳の合計が
    # 100%を超えて表示され得るため。
    # *100までBigDecimalで計算してから最後にto_fする理由: floatにしてから掛けると
    # 2進数誤差で「19.900000000000002%」のような値がAPIに乗ってしまう
    def self.ratio(value, base)
      return nil if base.nil? || base.zero? || value.nil?
      (value.to_d * 100 / base).truncate(RATIO_PRECISION).to_f
    end
    private_class_method :ratio
  end
end
