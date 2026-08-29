# CFは会計基準・業種によらず3区分+期首期末の構造が同一のため全形式共通
class Charts::Builders::CashFlow < Charts::Builders::StackBase
  # ラベルを短縮形にしている理由: X軸の目盛りにそのまま表示されるため、
  # 正式名称（営業活動によるキャッシュ・フロー等）では潰れて読めない
  STEPS = [
    [ "cashBegin", "期首残", "cf.cash_begin", "balance" ],
    [ "operating", "営業CF", "cf.operating",  "flow" ],
    [ "investing", "投資CF", "cf.investing",  "flow" ],
    [ "financing", "財務CF", "cf.financing",  "flow" ],
    [ "cashEnd",   "期末残", "cf.cash_end",   "balance" ]
  ].freeze

  def build
    # 5点すべて揃わなければ表示不可とする（all-or-nothing）。
    # 理由: ウォーターフォールは1点欠けると滝の繋がりが崩れ、誤解を招くグラフになる
    steps = STEPS.map { |key, label, code, kind|
      v = val(code)
      return Charts::WaterfallChart.unrenderable(no_data_note("キャッシュフロー")) if v.nil?
      # amountはStackChartと違い符号付きのまま渡す。増減の向きが情報そのものだから
      Charts::WaterfallStep.new(key: key, label: label, amount: v, kind: kind)
    }
    Charts::WaterfallChart.new(renderable: true, note: nil, steps: steps)
  end
end
