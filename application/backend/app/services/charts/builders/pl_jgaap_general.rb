# PLは貸借バランスが定義的に成立する（導出項目が差分を埋める）ため、
# two_sided_chart は使わずBuilderごとに組み立てる。共通ヘルパ（seg/ratio）のみ利用
class Charts::Builders::PlJgaapGeneral < Charts::Builders::StackBase
  # 費用の構成は業種で異なる。この順に試し、借方合計（費用+営業利益）が売上と1割以内で合う
  # 最初の構成で描く（開示されている科目だけを積む）。
  # 各要素は [科目コード, key, ラベル, 色の役割, ツールチップ表示名（labelと同じならnil）]:
  #   1. 内訳型: 売上原価・金融費用（証券）・販管費 … 一般事業会社の基本形
  #   2. 一括型: 営業費用 … 原価と販管費に分けず一括開示する業種（電気・特定金融・投資業など）
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

  # 借方[費用…, 営業利益] / 貸方[売上高(, 営業損失)]
  def build
    revenue = val("pl.revenue")
    op = val("pl.operating_profit")
    # 売上高と営業利益は日本基準の実質必須科目。無い=形式不一致か取込不良なので描画しない
    return unrenderable if revenue.nil? || revenue.zero? || op.nil?

    # どの構成でも貸借が合わなければ描画しない。原価・販管費の科目がフォールバックリスト外で
    # 取れていない企業をそのまま描くと、貸借の高さが合わない誤ったグラフになるため。
    # 乖離率の分母は売上にする（表示の基準線が売上のため）。
    # 費用科目が1つも取れない（=費用を開示しない持株会社の単体など）場合も、
    # 売上と営業利益で貸借が合うなら正常系として描く
    expenses = EXPENSE_STRUCTURES
                 .map { |specs| specs.filter_map { |code, key, label, role, tooltip| (v = val(code)) && [ key, label, v, role, tooltip ] } }
                 .find { |segs| within_tolerance?(revenue, segs.sum { |_, _, v, _, _| v } + op) }
    return unrenderable if expenses.nil?

    debit = expenses.map { |key, label, v, role, tooltip| seg(key, label, v, role, base: revenue, tooltip: tooltip) }
    credit = [ seg("revenue", "売上", revenue, "revenue", base: revenue) ]
    if op.negative?
      credit << seg("operatingLoss", "営業損失", -op, "loss", base: revenue, signed: op)
    else
      debit << seg("operatingProfit", "営業利益", op, "profit", base: revenue)
    end
    Charts::StackChart.new(renderable: true, note: nil,
                   bars: [ Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit) ])
  end

  private
    def unrenderable = Charts::StackChart.unrenderable(no_data_note("損益計算書"))
end
