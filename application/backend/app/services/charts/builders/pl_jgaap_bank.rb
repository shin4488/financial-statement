class Charts::Builders::PlJgaapBank < Charts::Builders::StackBase
  # 銀行: 借方[経常費用, 経常利益] / 貸方[経常収益(, 経常損失)]
  def build
    revenue = val("pl.ordinary_revenue")
    expenses = val("pl.ordinary_expenses")
    profit = val("pl.ordinary_profit")
    return Charts::StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。") if revenue.nil? || expenses.nil? || profit.nil?

    debit = [seg("ordinaryExpenses", "経常費用", expenses, "expense1", base: revenue)]
    credit = [seg("ordinaryRevenue", "経常収益", revenue, "revenue", base: revenue)]
    if profit.negative?
      credit << seg("ordinaryLoss", "経常損失", -profit, "loss", base: revenue, signed: profit)
    else
      debit << seg("ordinaryProfit", "経常利益", profit, "profit", base: revenue)
    end
    Charts::StackChart.new(renderable: true, note: nil,
                   bars: [Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit)])
  end
end
