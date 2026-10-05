# IFRS: 収益→税引前利益の骨格。中間科目（営業利益等）はIFRSでは開示任意で
# 企業間比較ができないため骨格から除外し、費用の内訳は「開示されている科目だけ」使う
class Charts::Builders::PlIfrs < Charts::Builders::StackBase
  def build
    revenue = val("pl.revenue")
    pbt = val("pl.profit_before_tax")
    return unrenderable if revenue.nil? || revenue.zero? || pbt.nil?

    expenses = sign_corrected(expense_specs, revenue)
    return unrenderable if expenses.nil?
    known_expenses = expenses.sum { |_, _, v, _| v }
    # その他損益（純額）= 開示された科目だけでは説明できない差分。
    # 内容は「その他営業損益 + 金融損益 + 持分法損益 等の純額」（正=収益側 / 負=費用側）。
    # この導出項目が差分を全部引き受けるため、借方合計=貸方合計が定義的に成立する
    other_net = pbt - (revenue - known_expenses)

    debit = expenses.map { |key, label, v, role| seg(key, label, v, role, base: revenue) }
    credit = [ seg("revenue", "収益", revenue, "revenue", base: revenue) ]
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
                   bars: [ Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit) ])
  end

  private
    # 原価+販管費型と営業費用一括型のどちらでもこの1つのリストで吸収する。
    # 営業費用は、売上原価・販管費と併記されるときはそれらの合計（同額か、符号だけが逆）として
    # 開示されている。一緒に積むと費用を二重に数え、実在しない大きな差額が出るため、
    # 売上原価か販管費があるときは営業費用を積まない
    def expense_specs
      specs = [
        [ "costOfSales", "売上原価",             val("pl.cost_of_sales"), "expense1" ],
        [ "sga",         "販売費及び一般管理費", val("pl.sga"),           "expense2" ]
      ].reject { |_, _, v, _| v.nil? }
      return specs if specs.any?
      [ [ "operatingExpenses", "営業費用", val("pl.operating_expenses"), "expense1" ] ].reject { |_, _, v, _| v.nil? }
    end

    # 費用のタグは正の値で付ける決まりだが、損益計算書の「△」の表示どおり負の値で付ける会社がある。
    # 符号の付け間違いと確かめられるのは、売上原価が負で、収益−売上原価の絶対値が売上総利益と
    # 一致するときだけ。そのときは費用を正の値として描き、確かめられなければ実際の値と合わないため描かない
    def sign_corrected(specs, revenue)
      return specs if specs.none? { |_, _, v, _| v.negative? }
      cost = val("pl.cost_of_sales")
      gross_profit = val("pl.gross_profit")
      return unless cost&.negative? && gross_profit
      return unless balanced?(revenue - cost.abs - gross_profit, %w[pl.revenue pl.cost_of_sales pl.gross_profit])
      specs.map { |key, label, v, role| [ key, label, v.abs, role ] }
    end

    def unrenderable = Charts::StackChart.unrenderable("損益計算書: この企業のIFRS損益計算書は表示に対応していません。")
end
