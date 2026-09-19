# 開示された損益科目を積み上げ、税引前利益まで検算する。残差科目は作らない。
class Charts::Builders::PlIfrs < Charts::Builders::StackBase
  COST = [ "pl.cost_of_sales", "costOfSales", "売上原価", "expense1" ].freeze
  SGA = [ "pl.sga", "sga", "販売費及び一般管理費", "expense2" ].freeze
  RESEARCH = [ "pl.research_and_development", "research", "研究開発費", "expense2" ].freeze
  EXPENSE_STRUCTURES = [
    [ COST, SGA ],
    [ COST, SGA, RESEARCH ],
    [ [ "pl.operating_expenses", "operatingExpenses", "営業費用", "expense1" ] ]
  ].freeze
  INCOME = [
    [ "pl.other_operating_income", "otherIncome", "その他収益", "revenue2" ],
    [ "pl.finance_income", "financeIncome", "金融収益", "revenue2" ],
    [ "pl.equity_method_profit", "equityMethod", "持分法投資損益", "revenue2" ]
  ].freeze
  EXPENSES = [
    [ "pl.other_operating_expenses", "otherExpenses", "その他費用", "expense3" ],
    [ "pl.finance_costs", "financeCosts", "金融費用", "expense3" ]
  ].freeze

  def build
    revenue = val("pl.revenue")
    profit = val("pl.profit_before_tax")
    return unrenderable unless revenue&.positive? && !profit.nil?

    incomes = INCOME.select { |code,| !val(code).nil? }
    if val("pl.other_operating_income").nil? && val("pl.other_operating_expenses").nil? && !val("pl.other_income_expenses_net").nil?
      incomes << [ "pl.other_income_expenses_net", "otherIncomeExpensesNet", "その他損益（開示純額）", "revenue2" ]
    end
    extras = EXPENSES.select { |code,| !val(code).nil? }
    structure = EXPENSE_STRUCTURES.find do |specs|
      codes = (specs + extras).map(&:first).select { |code| !val(code).nil? }
      codes.any? && codes.all? { |code| val(code) >= 0 } &&
        reconciles?([ "pl.revenue" ] + incomes.map(&:first), codes + [ "pl.profit_before_tax" ])
    end
    return unrenderable unless structure

    debit = (structure + extras).filter_map { |code, key, label, role|
      seg(key, label, val(code), role, base: revenue) unless val(code).nil? }
    credit = [ seg("revenue", "収益", revenue, "revenue", base: revenue) ]
    incomes.each do |code, key, label, role|
      value = val(code)
      (value.negative? ? debit : credit) << seg(key, label, value.abs, role, base: revenue, signed: value)
    end
    if profit.negative?
      credit << seg("lossBeforeTax", "税引前損失", profit.abs, "loss", base: revenue, signed: profit)
    else
      debit << seg("profitBeforeTax", "税引前利益", profit, "profit", base: revenue)
    end
    Charts::StackChart.new(renderable: true, note: nil,
      bars: [ Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit) ])
  end

  private
    def unrenderable
      Charts::StackChart.unrenderable("損益計算書: 開示された収益・費用・税引前利益の関係を確認できないため表示に対応していません。")
    end
end
