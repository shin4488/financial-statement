# PLは貸借バランスが定義的に成立する（導出項目が差分を埋める）ため、
# two_sided_chart は使わずBuilderごとに組み立てる。共通ヘルパ（seg/ratio）のみ利用
class Charts::Builders::PlJgaapGeneral < Charts::Builders::StackBase
  # 費用セグメントの定義（key, ラベル, 色の役割）
  EXPENSE_SEGMENTS = {
    "pl.cost_of_sales"      => [ "costOfSales",       "売上原価",       "expense1" ],
    "pl.financial_expenses" => [ "financialExpenses", "金融費用",       "expense1" ],
    "pl.sga"                => [ "sga",               "販売一般管理費", "expense2" ],
    "pl.operating_expenses" => [ "operatingExpenses", "営業費用",       "expense1" ]
  }.freeze
  # 費用の構成は業種で異なる。この順に試し、借方合計（費用+営業利益）が売上と1割以内で合う
  # 最初の構成で描く（開示されている科目だけを積む）:
  #   1. 内訳型: 売上原価・金融費用（証券）・販管費 … 一般事業会社の基本形
  #   2. 一括型: 営業費用 … 原価と販管費に分けず一括開示する業種（電気・特定金融・投資業など）
  # 内訳型を先に試す理由: 営業費用の合計と内訳を併記する企業（鉄道の連結など）では
  # 内訳の方が情報量が多く、一括型を先にすると内訳が捨てられるため
  EXPENSE_STRUCTURES = [
    %w[pl.cost_of_sales pl.financial_expenses pl.sga],
    %w[pl.operating_expenses]
  ].freeze

  # 借方[費用…, 営業利益] / 貸方[売上高(, 営業損失)]
  def build
    revenue = val("pl.revenue")
    op = val("pl.operating_profit")
    # 売上高と営業利益は日本基準の実質必須科目。無い=形式不一致か取込不良なので描画しない
    return unrenderable if revenue.nil? || revenue.zero? || op.nil?

    # どの構成でも貸借が合わなければ描画しない。原価・販管費の科目がフォールバックリスト外で
    # 取れていない企業をそのまま描くと、貸借の高さが合わない誤ったグラフになるため。
    # balanced?の第1引数は乖離率の分母。ここでは売上を分母にする（表示の基準線が売上のため）
    expenses = EXPENSE_STRUCTURES
                 .map { |codes| codes.filter_map { |code| (v = val(code)) && [ code, v ] } }
                 .find { |pairs| balanced?(revenue, pairs.sum { |_, v| v } + op) }
    return unrenderable if expenses.nil?

    debit = expenses.map do |code, v|
      key, label, role = EXPENSE_SEGMENTS.fetch(code)
      seg(key, label, v, role, base: revenue)
    end
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
    def unrenderable = Charts::StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。")
end
