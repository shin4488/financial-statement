module Charts
  module Builders
    class StackBase
      RATIO_PRECISION = 1 # %表示の小数桁数
      # 「描けない」の共通文言。個別の理由を説明できる形式（ifrs_summaryなど）だけ独自文言を使う
      NO_DATA_NOTE = "データがない、または表示対応していないデータです。".freeze

      def initialize(items)
        @items = items # {item_code => amount} (Disclosure::FinancialStatement#items_hash)
      end

      private
        def val(code) = @items[code]

        def no_data_note(statement_label) = "#{statement_label}: #{NO_DATA_NOTE}"

        # 比率は%値（損失は負、収益を上回る費用などは100を超える）。truncate（切り捨て）を使う理由: 四捨五入だと内訳の合計が
        # 100%を超えて表示され得るため。
        # *100までBigDecimalで計算してから最後にto_fする理由: floatにしてから掛けると
        # 2進数誤差で「19.900000000000002%」のような値がAPIに乗ってしまう
        def ratio(value, base)
          return nil if base.nil? || base.zero? || value.nil?
          (value.to_d * 100 / base).truncate(RATIO_PRECISION).to_f
        end

        # Segmentの生成規約:
        #   amount       = 描画高さ。絶対値（rechartsに負を渡すと棒が逆向きに描かれるため）
        #   signed_amount= 実値。ツールチップ表示用。signed引数で明示指定がなければamountと同じ
        #   ratio        = signed基準で計算（損失なら負の%になり「-3.1%」と表示される）
        #   tooltip      = ツールチップ専用の表示名（未指定ならlabelが表示される）
        def seg(key, label, amount, role, base:, signed: nil, tooltip: nil)
          Segment.new(key: key, label: label, amount: amount.abs,
                      signed_amount: signed || amount, ratio: ratio(signed || amount, base),
                      color_role: role, tooltip_label: tooltip)
        end

        # 貸借2本構成の共通組み立て:
        # - specs: [key, label, item_code, color_role] の配列。金額nilの科目はスキップ
        # - equity(資本・純資産)が負なら3本目バー（spacer + 資本のマイナス表示）
        # - 貸借合計の乖離が開示精度超なら描画不可
        # 債務超過表示・貸借検証は形式によらず同じ問題なので、ここに1回だけ実装する
        # （形式別Builderに書かせない = 新形式追加時にこのロジックの再実装漏れが起きない）
        def two_sided_chart(debit_specs:, credit_specs:, equity:, equity_label:, base:, unrenderable_note:)
          return StackChart.unrenderable(unrenderable_note) unless base&.positive? &&
            reconciles?([ "bs.assets" ], [ "bs.liabilities", "bs.equity" ])
          # 内訳が合計を説明できなければ、実在する合計を表示する。
          debit_codes = debit_specs.map { |_, _, code, _| code }.select { |code| !val(code).nil? }
          credit_codes = credit_specs.map { |_, _, code, _| code }.select { |code| !val(code).nil? }
          unless reconciles?([ "bs.assets" ], debit_codes)
            debit_specs = [ [ "assets", "資産合計", "bs.assets", "asset1" ] ]
          end
          unless reconciles?([ "bs.liabilities" ], credit_codes)
            credit_specs = [ [ "liabilities", "負債合計", "bs.liabilities", "liability1" ] ]
          end
          debit = build_segments(debit_specs, base)
          credit = build_segments(credit_specs, base)
          return StackChart.unrenderable(unrenderable_note) if debit.empty? || equity.nil?

          return StackChart.unrenderable(unrenderable_note) if
            (debit + credit).any? { |segment| segment.signed_amount.negative? }

          bars = [ Bar.new(label: "借方", segments: debit) ]
          if equity.negative?
            # 債務超過: 貸方は負債のみ（負債合計 > 資産合計の状態）。3本目のバーで
            # 「資産と負債の差 = マイナスの純資産」を可視化する。
            # spacer = 資産合計と同じ高さまで透明で詰めて、負債を超えた部分にだけ
            # 赤いセグメントが現れるようにする位置合わせ
            bars << Bar.new(label: "貸方", segments: credit)
            spacer_amount = credit.sum(&:amount) + equity # = 負債合計 - |純資産| = 資産合計
            bars << Bar.new(label: "債務超過", segments: [
              seg("spacer", "", spacer_amount, "spacer", base: nil), # base:nil → ratio非表示
              # 債務超過でも色はequityのまま（負であることはラベル・ツールチップの負値で伝える）
              seg("equity", equity_label, -equity, "equity", base: base, signed: equity)
            ])
          else
            bars << Bar.new(label: "貸方",
                            segments: credit + [ seg("equity", equity_label, equity, "equity", base: base) ])
          end
          StackChart.new(renderable: true, note: nil, bars: bars)
        end

        def build_segments(specs, base)
          specs.filter_map do |key, label, code_or_value, role|
            value = code_or_value.is_a?(String) ? val(code_or_value) : code_or_value
            next if value.nil?
            seg(key, label, value, role, base: base)
          end
        end

        # 開示値の等式を検算する。未知の精度には許容差を推測しない。
        def reconciles?(left_codes, right_codes)
          codes = left_codes + right_codes
          return false if codes.any? { |code| val(code).nil? }
          difference = (left_codes.sum { |code| val(code) } - right_codes.sum { |code| val(code) }).abs
          return true if difference.zero?
          return false unless @items.respond_to?(:rounding_errors)
          errors = codes.map { |code| @items.rounding_errors[code] }
          errors.none?(&:nil?) && difference < errors.sum
        end
    end
  end
end
