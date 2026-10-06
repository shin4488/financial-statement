# PLは貸借バランスが定義的に成立する（導出項目が差分を埋める）ため、
# two_sided_chart は使わずBuilderごとに組み立てる。共通ヘルパ（seg/ratio）のみ利用
class Charts::Builders::PlJgaapGeneral < Charts::Builders::StackBase
  # 費用の構成は業種で異なる。開示されている科目だけを積み、費用を差額で求めることはしない。
  # 各要素は [科目コード, key, ラベル, 色の役割, ツールチップ表示名（labelと同じならnil）]:
  #   1. 内訳型: 売上原価・金融費用（証券）・販管費 … 一般事業会社の基本形
  #   2. 一括型: 営業費用 … 原価と販管費に分けず一括開示する業種（電気・特定金融・信販・投資業など）
  #   3. 原価+営業費用型: 売上原価と、その控除後の営業費用 … 商品先物取引業
  # 内訳型を先に試す理由: 営業費用の合計と内訳を併記する企業（鉄道の連結など）では
  # 内訳の方が情報量が多く、一括型を先にすると内訳が捨てられるため。
  # 一括型を原価+営業費用型より先に試す理由: 営業費用が売上原価を含む合計の業種（特定金融）で
  # 原価を二重に積まないため（合計なら2で先に合う）。
  # 営業費用の色が構成で違う理由: 一括型の営業費用は原価を含む合計（=原価の位置づけ）なので
  # 原価と同じ色、原価+営業費用型では原価控除後の費用（=販管費の位置づけ）なので販管費と同じ色にする
  # （同じ色だと売上原価との境界が見えなくなる）。
  # 「営業費用」の中身が構成で違う（原価込みか、原価控除後か）ことはツールチップ表示名で補足する。
  # バー内ラベルに足さないのは、バー幅で折り返し・見切れが起きるため
  EXPENSE_STRUCTURES = [
    [ [ "pl.cost_of_sales",      "costOfSales",       "売上原価",       "expense1", nil ],
      [ "pl.financial_expenses", "financialExpenses", "金融費用",       "expense1", nil ],
      [ "pl.sga",                "sga",               "販売一般管理費", "expense2", nil ] ],
    [ [ "pl.operating_expenses", "operatingExpenses", "営業費用",       "expense1", "営業費用（原価を含む）" ] ],
    [ [ "pl.cost_of_sales",      "costOfSales",       "売上原価",       "expense1", nil ],
      [ "pl.operating_expenses", "operatingExpenses", "営業費用",       "expense2", "営業費用（原価を除く）" ] ]
  ].freeze

  # 原価に当たる費用を「営業費用」として開示し、別に販管費を並べる会社の構成。
  # 営業費用が販管費を含む合計の会社では販管費を二重に数えてしまうため、両方の科目が取れていて
  # 左右が端数の範囲で一致するときだけ使い、一括型より後に試す
  OPERATING_EXPENSES_AND_SGA =
    [ [ "pl.operating_expenses", "operatingExpenses", "営業費用",       "expense1", "営業費用（販管費を除く）" ],
      [ "pl.sga",                "sga",               "販売一般管理費", "expense2", nil ] ].freeze

  # 選んだ費用の構成。balancedは、左右（費用+営業利益と売上）が端数の範囲で一致するか
  Expenses = Struct.new(:segments, :codes, :balanced, keyword_init: true)
  private_constant :Expenses

  # 借方[費用…, 営業利益] / 貸方[売上高(, 営業損失)]。売上0の会社は 借方[費用…] / 貸方[営業損失]
  def build
    revenue = val("pl.revenue")
    op = val("pl.operating_profit")
    expenses = selected_expenses
    return unrenderable if expenses.nil?

    # 比率の分母は売上（表示の基準線が売上のため）。売上0の会社は、費用の合計と一致する営業損失を分母にする
    base = revenue.zero? ? -op : revenue
    debit = expenses.segments.map { |key, label, v, role, tooltip| seg(key, label, v, role, base: base, tooltip: tooltip) }
    credit = revenue.zero? ? [] : [ seg("revenue", "売上", revenue, "revenue", base: base) ]
    if op.negative?
      credit << seg("operatingLoss", "営業損失", -op, "loss", base: base, signed: op)
    else
      debit << seg("operatingProfit", "営業利益", op, "profit", base: base)
    end
    Charts::StackChart.new(renderable: true, note: nil,
                   bars: [ Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit) ])
  end

  # 描くグラフの左右が端数の範囲で一致しないときの、照合に使った金額（取込のときにSentryへ警告する）
  def mismatch
    expenses = selected_expenses
    return if expenses.nil? || expenses.balanced
    [ "pl.revenue", *expenses.codes, "pl.operating_profit" ].to_h { |code| [ code, val(code) ] }
  end

  private
    # 1. 費用のタグだけの構成のうち、左右が端数の範囲で一致する最初の構成で描く
    # 2. なければ、今までの3つの構成のうち、左右の差が売上の1割以内の最初の構成で描き、ずれは警告で知らせる
    # どちらもなければ描かない。原価・販管費の科目がフォールバックリスト外で取れていない企業をそのまま描くと、
    # 貸借の高さが合わない誤ったグラフになるため。
    # 費用科目が1つも取れない（=費用を開示しない持株会社の単体など）場合も、売上と営業利益で貸借が合うなら描く
    def selected_expenses
      return @selected_expenses if defined?(@selected_expenses)
      @selected_expenses = select_expenses
    end

    def select_expenses
      revenue = val("pl.revenue")
      op = val("pl.operating_profit")
      # 売上高と営業利益は日本基準の実質必須科目。無い=形式不一致か取込不良なので描画しない
      return if revenue.nil? || op.nil?
      # 売上0（売上の行が「－」）の会社は、費用の合計と営業損失が一致するときだけ描く
      return if revenue.zero? && !op.negative?

      structures = EXPENSE_STRUCTURES.map { |specs| expenses(specs) }
      both = expenses(OPERATING_EXPENSES_AND_SGA)
      candidates = both.codes.size == OPERATING_EXPENSES_AND_SGA.size ? structures + [ both ] : structures
      balanced = candidates.find do |expenses|
        balanced?(revenue - expenses.segments.sum { |_, _, v, _, _| v } - op, [ "pl.revenue", *expenses.codes, "pl.operating_profit" ])
      end
      return balanced.tap { |expenses| expenses.balanced = true } if balanced
      return if revenue.zero?
      structures.find { |expenses| within_tolerance?(revenue, expenses.segments.sum { |_, _, v, _, _| v } + op) }
    end

    def expenses(specs)
      segments = []
      codes = []
      specs.each do |code, key, label, role, tooltip|
        next if (v = val(code)).nil?
        segments << [ key, label, v, role, tooltip ]
        codes << code
      end
      other_gas_costs = %w[pl.gas_miscellaneous_expenses pl.gas_incidental_expenses].reject { |code| val(code).nil? }
      cost = segments.find { |key, *| key == "costOfSales" }
      if cost && other_gas_costs.any?
        # ガスの全社売上と範囲を揃える。小さな費用を別段にしてラベルを重ねず、
        # 同じ費用色の「売上原価等」に集約し、含む費用名はツールチップで明示する。
        cost[1] = "売上原価等"
        cost[2] += other_gas_costs.sum { |code| val(code) }
        cost[4] = "売上原価・営業雑費用・附帯事業費用"
        codes += other_gas_costs
      end
      Expenses.new(segments: segments, codes: codes, balanced: false)
    end

    def unrenderable = Charts::StackChart.unrenderable(no_data_note("損益計算書"))
end
