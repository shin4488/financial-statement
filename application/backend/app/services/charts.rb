# チャートのデータ構造は名前空間ファイルにまとめて定義する。
# 1 Struct = 1ファイルに分けない理由: Zeitwerkは「1ファイル=1定数」を要求するが、
# この5つは常にセットで使う小さな値オブジェクトであり、分割すると見通しが悪くなるだけのため
module Charts
  # amount: 描画高さ（常に0以上） / signed_amount: 実際の値（ツールチップ表示用）。
  # 分ける理由: 負値をそのまま棒グラフに渡すと逆向きに描画されるため、
  # 「高さは正・実値は符号付き」を契約レベルで分離してフロントの分岐をなくす
  # color_role: フロントのパレット対応キー（意味ベースの固定enum。科目名ではなく役割で塗る）
  # tooltip_label: ツールチップだけ補足つきの名前にしたい科目用（nilならlabelを表示）。
  # バー内ラベルはバー幅で折り返し・見切れが起きるため補足を足せないが、ツールチップは
  # 文字に合わせて広がるので、注釈はこちらにだけ載せる
  Segment = Struct.new(:key, :label, :amount, :signed_amount, :ratio, :color_role, :tooltip_label,
                       keyword_init: true)
  Bar = Struct.new(:label, :segments, keyword_init: true)
  StackChart = Struct.new(:renderable, :note, :bars, keyword_init: true) do
    def self.unrenderable(note) = new(renderable: false, note: note, bars: [])
  end

  # kind: "balance" | "flow"。color_roleは増減の向き（cashIncrease / cashDecrease）:
  # StackChartのSegmentと同じく「色の決定はバックエンド」の契約に揃え、フロントに符号の再解釈をさせない
  WaterfallStep = Struct.new(:key, :label, :amount, :kind, :color_role, keyword_init: true)
  WaterfallChart = Struct.new(:renderable, :note, :steps, keyword_init: true) do
    def self.unrenderable(note) = new(renderable: false, note: note, steps: [])
  end
end
