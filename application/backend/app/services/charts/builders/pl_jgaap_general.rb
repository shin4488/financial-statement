# PLは貸借バランスが定義的に成立する（導出項目が差分を埋める）ため、
# two_sided_chart は使わずBuilderごとに組み立てる。共通ヘルパ（seg/ratio）のみ利用
class Charts::Builders::PlJgaapGeneral < Charts::Builders::StackBase
  # 借方[原価, 販管費, 営業利益] / 貸方[売上高(, 営業損失)]
  def build
    revenue = val("pl.revenue")
    op = val("pl.operating_profit")
    # 売上高と営業利益は日本基準一般の実質必須科目。無い=形式不一致か取込不良なので描画しない
    return Charts::StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。") if revenue.nil? || revenue.zero? || op.nil?

    # 原価・販管費は .to_i でnil→0に倒す: 原価を持たない持株会社等でも
    # 「売上と営業利益だけの構成」で描画を継続する。IFRS（PlIfrs）と違い導出項目を挟まないのは、
    # 日本基準では 売上-原価-販管費=営業利益 が制度上ほぼ成立し、残差処理が不要なため
    cost_of_sales = val("pl.cost_of_sales").to_i
    sga = val("pl.sga").to_i
    # 借方合計（原価+販管費+営業利益）が売上と1割超乖離したら描画しない。
    # 原価・販管費の科目がフォールバックリスト外（営業収益型の業種など）で取れていない企業を
    # そのまま描くと、貸借の高さが合わない誤ったグラフになるため。
    # balanced?の第1引数は乖離率の分母。ここでは売上を分母にする（表示の基準線が売上のため）
    debit_total = cost_of_sales + sga + op
    return Charts::StackChart.unrenderable("損益計算書: データがない、または表示対応していないデータです。") unless balanced?(revenue, debit_total)

    debit = [
      seg("costOfSales", "売上原価",       cost_of_sales, "expense1", base: revenue),
      seg("sga",         "販売一般管理費", sga,           "expense2", base: revenue),
    ]
    credit = [seg("revenue", "売上", revenue, "revenue", base: revenue)]
    if op.negative?
      credit << seg("operatingLoss", "営業損失", -op, "loss", base: revenue, signed: op)
    else
      debit << seg("operatingProfit", "営業利益", op, "profit", base: revenue)
    end
    Charts::StackChart.new(renderable: true, note: nil,
                   bars: [Charts::Bar.new(label: "借方", segments: debit), Charts::Bar.new(label: "貸方", segments: credit)])
  end
end
