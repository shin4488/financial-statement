# IFRS: 収益→税引前利益の骨格。中間科目（営業利益等）はIFRSでは開示任意で
# 企業間比較ができないため骨格から除外し、費用の内訳は「開示されている科目だけ」使う
class Charts::Builders::PlIfrs < Charts::Builders::StackBase
  # 費用の内訳。各要素は [key, ラベル, 科目コード, 色の役割]
  BREAKDOWN = [
    [ "costOfSales", "売上原価",             "pl.cost_of_sales", "expense1" ],
    [ "sga",         "販売費及び一般管理費", "pl.sga",           "expense2" ]
  ].freeze
  # 売上0の会社（創薬ベンチャーなど）は、研究開発費・一般管理費を販管費と別の行で開示することがある。
  # 研究開発費のタグはほかの費用と重ねて付けられることがあり、売上がある会社のグラフに加えると今の描き方が変わるため、
  # 売上0のグラフだけで使う（売上0のグラフは費用の合計が営業損失と一致するときだけ描くので、重ねて数えれば描かれない）
  ZERO_REVENUE_BREAKDOWN = (BREAKDOWN + [
    [ "researchAndDevelopment",   "研究開発費", "pl.research_and_development",            "expense1" ],
    [ "generalAndAdministrative", "一般管理費", "pl.general_and_administrative_expenses", "expense2" ]
  ]).freeze
  OPERATING_EXPENSES = [ "operatingExpenses", "営業費用", "pl.operating_expenses", "expense1" ].freeze

  def build
    return zero_revenue_chart if val("pl.revenue")&.zero?
    expenses = drawn_expenses
    return unrenderable if expenses.nil?
    revenue = val("pl.revenue")
    pbt = val("pl.profit_before_tax")
    # 差額 = 表示した費用だけでは説明できない残り（その他の営業損益・金融損益・持分法損益などの純額。正=収益側 / 負=費用側）。
    # 収益・税引前利益・表示した費用が実際の値なら、損益計算書の残りの行の合計と一致し、借方合計=貸方合計になる
    other_net = pbt - (revenue - expenses.sum { |_, _, v, _, _| v })

    debit = expenses.map { |key, label, v, role, _| seg(key, label, v, role, base: revenue) }
    credit = [ seg("revenue", "収益", revenue, "revenue", base: revenue) ]
    # 差額の名前は、有報で一般的な「その他の収益」「その他の費用」「費用」を使い、積まれる側で分ける。
    # 表示した費用がなければ通常の費用がすべて差額に入るため、「その他」と書くと一部の費用だけに見えてしまう。
    # expense3/revenue2はどちらも差額専用のロール。実在の科目（原価・販管費・収益）と同系色だと
    # 差額だと見分けがつかないため、どちら側に積まれても同じ専用色になるようロールを分けている
    if other_net.negative?
      label = expenses.empty? ? "費用（純額）" : "その他の費用（純額）"
      debit << seg("otherNet", label, -other_net, "expense3", base: revenue, signed: other_net)
    elsif other_net.positive?
      credit << seg("otherNet", "その他の収益（純額）", other_net, "revenue2", base: revenue)
    end
    # other_net.zero? の場合はセグメント自体を出さない（高さ0の積み上げは無意味なため）
    if pbt.negative?
      # 赤字は貸方に「税引前損失」として積む: 借方（費用）が貸方（収益）より高いとき、
      # その差を貸方側に埋めることで2本の高さを揃える（日本基準の営業損失と同じ表現）
      credit << seg("lossBeforeTax", "税引前損失", -pbt, "loss", base: revenue, signed: pbt)
    else
      debit << seg("profitBeforeTax", "税引前利益", pbt, "profit", base: revenue)
    end
    chart(debit, credit)
  end

  # 営業費用を積まないときの前提（営業費用は売上原価・販管費の合計）が端数の範囲で成り立たないときの、照合に使った金額。
  # 成り立たなければ、積まなかった営業費用に原価・販管費以外の費用が含まれ、差額に入っている（取込のときにSentryへ警告する）。
  # 差額が残りを引き受けるため左右の高さは必ず合い、負の値の費用は確かめられたときだけ描くため、ほかに照合する式はない
  def mismatch
    operating_expenses = val("pl.operating_expenses")
    breakdown = BREAKDOWN.map { |_, _, code, _| code }.reject { |code| val(code).nil? }
    return if drawn_expenses.nil? || operating_expenses.nil? || breakdown.empty?
    codes = breakdown + [ "pl.operating_expenses" ]
    return if balanced?(operating_expenses.abs - breakdown.sum { |code| val(code) }.abs, codes)
    codes.to_h { |code| [ code, val(code) ] }
  end

  private
    # 収益と税引前利益がそろい、費用の符号を確かめられたときに積む費用。描けなければnil
    def drawn_expenses
      return @drawn_expenses if defined?(@drawn_expenses)
      revenue = val("pl.revenue")
      drawable = revenue && !revenue.zero? && val("pl.profit_before_tax")
      @drawn_expenses = drawable ? sign_corrected(expense_specs(BREAKDOWN), revenue) : nil
    end

    # 売上0の会社は、費用の合計が営業損失と端数の範囲で一致するときだけ、借方に費用、貸方に営業損失を積んで描く。
    # 一致しなければ、その他の営業収益などが営業損失に含まれ、費用を差額で求めないと描けないため描かない。
    # 負の値の費用は、売上総利益がなく符号の付け間違いを確かめられないため描かない。
    # 比率の分母は、費用の合計と一致する営業損失にする
    def zero_revenue_chart
      op = val("pl.operating_profit")
      specs = expense_specs(ZERO_REVENUE_BREAKDOWN)
      return unrenderable if op.nil? || !op.negative? || specs.empty? || specs.any? { |_, _, v, _, _| v.negative? }
      codes = specs.map { |_, _, _, _, code| code } + [ "pl.operating_profit" ]
      return unrenderable unless balanced?(-op - specs.sum { |_, _, v, _, _| v }, codes)

      debit = specs.map { |key, label, v, role, _| seg(key, label, v, role, base: -op) }
      chart(debit, [ seg("operatingLoss", "営業損失", -op, "loss", base: -op, signed: op) ])
    end

    # 原価+販管費型と営業費用一括型のどちらでもこの形で吸収する。内訳の科目があれば内訳を積み、なければ営業費用を積む。
    # 営業費用は、内訳と併記されるときはそれらの合計（同額か、符号だけが逆）として開示されている。
    # 一緒に積むと費用を二重に数え、実在しない大きな差額が出るため、内訳があるときは営業費用を積まない。
    # 各要素は [key, ラベル, 金額, 色の役割, 科目コード]
    def expense_specs(breakdown)
      specs = breakdown.filter_map { |key, label, code, role| [ key, label, val(code), role, code ] unless val(code).nil? }
      return specs if specs.any?
      key, label, code, role = OPERATING_EXPENSES
      val(code).nil? ? [] : [ [ key, label, val(code), role, code ] ]
    end

    # 費用のタグは正の値で付ける決まりだが、損益計算書の「△」の表示どおり負の値で付ける会社がある。
    # 符号の付け間違いと確かめられるのは、売上原価が負で、収益−売上原価の絶対値が売上総利益と
    # 一致するときだけ。そのときは費用を正の値として描き、確かめられなければ実際の値と合わないため描かない
    def sign_corrected(specs, revenue)
      return specs if specs.none? { |_, _, v, _, _| v.negative? }
      cost = val("pl.cost_of_sales")
      gross_profit = val("pl.gross_profit")
      return unless cost&.negative? && gross_profit
      return unless balanced?(revenue - cost.abs - gross_profit, %w[pl.revenue pl.cost_of_sales pl.gross_profit])
      specs.map { |key, label, v, role, code| [ key, label, v.abs, role, code ] }
    end

    def chart(debit, credit)
      Charts::StackChart.new(renderable: true, note: nil,
                             bars: [ Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit) ])
    end

    def unrenderable = Charts::StackChart.unrenderable("損益計算書: この企業のIFRS損益計算書は表示に対応していません。")
end
