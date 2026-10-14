module Charts
  # 貸借2本構成の共通組み立て:
  # - debit_specs・credit_specs: [key, label, item_code or 金額, color_role] の配列。金額nilの科目はスキップ
  # - equity(資本・純資産)が負なら3本目バー（spacer + 資本のマイナス表示）
  # - 貸借合計の乖離がTOLERANCE超なら描画不可
  # 債務超過表示・貸借検証は形式によらず同じ問題なので、ここに1回だけ実装する
  # （形式別Builderに書かせない = 新形式追加時にこのロジックの再実装漏れが起きない）
  class TwoSidedChart
    # chart: 組み立てたStackChart。
    # mismatch: 描いたとき、借方の科目の合計＝資産合計、資産合計＝負債合計＋純資産合計 が端数の範囲で成り立たなければ、
    # 式に使った金額（{科目コード => 金額}）。描かないときはnil
    attr_reader :chart, :mismatch

    def initialize(items, debit_specs:, credit_specs:, equity:, equity_label:, base:, unrenderable_note:)
      @items = items
      @mismatch = nil
      @chart = build(debit_specs, credit_specs, equity, equity_label, base, unrenderable_note)
    end

    private
      def val(code) = @items[code]

      def build(debit_specs, credit_specs, equity, equity_label, base, unrenderable_note)
        debit = build_segments(debit_specs, base)
        credit = build_segments(credit_specs, base)
        return StackChart.unrenderable(unrenderable_note) if debit.empty? || equity.nil?

        # 貸借検証は「バーを組む前」に生の値で行う。バー構築後のセグメント合計で検証すると、
        # 債務超過時に挿入するspacer（描画用の詰め物）まで合計に含まれ常に不一致になる
        debit_total = debit.sum(&:amount)
        credit_total = credit.sum(&:signed_amount) + equity
        if debit_total.zero?
          # 資産が0の会社（統合の準備会社など）は、資産を分母にした比率を出せない。負債＋純資産もほぼ0（負債と同じ額の債務超過）の
          # ときだけ、借方に何も積まずに描き、負債を分母にする。資産0で貸借が合わないものは、取込不良のおそれがあるため描かない
          liabilities_total = credit.sum(&:signed_amount)
          return StackChart.unrenderable(unrenderable_note) unless liabilities_total.positive? &&
                                                                   Tolerance.within?(liabilities_total, -equity)
          debit = []
          base = liabilities_total
          credit = build_segments(credit_specs, base)
        elsif !Tolerance.within?(debit_total, credit_total)
          return StackChart.unrenderable(unrenderable_note)
        end

        bars = [ Bar.new(label: "借方", segments: debit) ]
        if equity.negative?
          # 債務超過: 貸方は負債のみ（負債合計 > 資産合計の状態）。3本目のバーで
          # 「資産と負債の差 = マイナスの純資産」を可視化する。
          # spacer = 資産合計と同じ高さまで透明で詰めて、負債を超えた部分にだけ
          # 赤いセグメントが現れるようにする位置合わせ
          bars << Bar.new(label: "貸方", segments: credit)
          spacer_amount = credit.sum(&:amount) + equity # = 負債合計 - |純資産| = 資産合計
          bars << Bar.new(label: "債務超過", segments: [
            Segments.segment("spacer", "", spacer_amount, "spacer", base: nil), # base:nil → ratio非表示
            # 債務超過でも色はequityのまま（負であることはラベル・ツールチップの負値で伝える）
            Segments.segment("equity", equity_label, -equity, "equity", base: base, signed: equity)
          ])
        else
          bars << Bar.new(label: "貸方",
                          segments: credit + [ Segments.segment("equity", equity_label, equity, "equity", base: base) ])
        end
        @mismatch = balance_mismatch(debit_specs, debit)
        StackChart.new(renderable: true, note: nil, bars: bars)
      end

      # 借方の合計が資産合計に届かなければ、描いていない資産の科目が残っている。合計行どうしが合わなければ、取込でタグを取り違えたおそれがある。
      # 貸方は、流動負債・固定負債のほかの負債（特別法上の準備金など）を差額でしか描けないため、合計行どうしだけを照合する。
      # 借方の残差（銀行・保険のその他資産など）は資産合計から求めるため、借方の合計は必ず合う
      def balance_mismatch(debit_specs, debit)
        assets, liabilities, equity = %w[bs.assets bs.liabilities bs.equity].map { |code| val(code) }
        return if assets.nil?
        debit_codes = debit_specs.filter_map { |_, _, code, _| code if code.is_a?(String) && !val(code).nil? }
        checks = [ [ debit.sum(&:signed_amount) - assets, debit_codes + [ "bs.assets" ] ] ]
        checks << [ assets - liabilities - equity, %w[bs.assets bs.liabilities bs.equity] ] if liabilities && equity
        return if checks.all? { |difference, codes| Tolerance.balanced?(@items, difference, codes) }
        (debit_codes + %w[bs.assets bs.liabilities bs.equity]).to_h { |code| [ code, val(code) ] }.compact
      end

      def build_segments(specs, base)
        specs.filter_map do |key, label, code_or_value, role|
          value = code_or_value.is_a?(String) ? val(code_or_value) : code_or_value
          next if value.nil?
          Segments.segment(key, label, value, role, base: base)
        end
      end
  end
end
