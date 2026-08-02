# IFRS: 収益→税引前利益の骨格。中間科目（営業利益等）はIFRSでは開示任意で
# 企業間比較ができないため骨格から除外し、費用の内訳は「開示されている科目だけ」使う
class Charts::Builders::PlIfrs < Charts::Builders::StackBase
  def build
    revenue = val("pl.revenue")
    pbt = val("pl.profit_before_tax")
    return Charts::StackChart.unrenderable("損益計算書: この企業のIFRS損益計算書は表示に対応していません。") if revenue.nil? || revenue.zero? || pbt.nil?

    # 原価+販管費型と営業費用一括型のどちらでもこの1つのリストで吸収できる
    # （両方同時に開示される企業は想定しない。両方あれば両方積まれるが
    #   その場合はother_netが差分を吸収するので貸借は崩れない）
    expense_specs = [
      ["costOfSales",       "売上原価",             val("pl.cost_of_sales"),      "expense1"],
      ["sga",               "販売費及び一般管理費", val("pl.sga"),                "expense2"],
      ["operatingExpenses", "営業費用",             val("pl.operating_expenses"), "expense1"],
    ].reject { |_, _, v, _| v.nil? }
    known_expenses = expense_specs.sum { |_, _, v, _| v }
    # その他損益（純額）= 開示された科目だけでは説明できない差分。
    # 内容は「その他営業損益 + 金融損益 + 持分法損益 等の純額」（正=収益側 / 負=費用側）。
    # この導出項目が差分を全部引き受けるため、借方合計=貸方合計が定義的に成立する
    other_net = pbt - (revenue - known_expenses)

    debit = expense_specs.map { |key, label, v, role| seg(key, label, v, role, base: revenue) }
    credit = [seg("revenue", "収益", revenue, "revenue", base: revenue)]
    if other_net.negative?
      # expense3/revenue2はどちらも「導出項目」専用のロール。
      # 実在の科目（原価・販管費・収益）と同系色だと導出項目だと見分けがつかないため、
      # どちら側に積まれても同じ専用色になるようロールを分けている
      debit << seg("otherNet", "その他損益（純額）", -other_net, "expense3", base: revenue, signed: other_net)
    elsif other_net.positive?
      credit << seg("otherNet", "その他損益（純額）", other_net, "revenue2", base: revenue)
    end
    # other_net.zero? の場合はセグメント自体を出さない（高さ0の積み上げは無意味なため）
    if pbt.negative?
      # 赤字は貸方に「税引前損失」として積む: 借方（費用）が貸方（収益）より高いとき、
      # その差を貸方側に埋めることで2本の高さを揃える（日本基準の営業損失と同じ表現）
      credit << seg("lossBeforeTax", "税引前損失", -pbt, "loss", base: revenue, signed: pbt)
    else
      debit << seg("profitBeforeTax", "税引前利益", pbt, "profit", base: revenue)
    end
    Charts::StackChart.new(renderable: true, note: nil,
                   bars: [Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit)])
  end
end
