module Charts
  module Builders
    class StackBase
      RATIO_PRECISION = 1 # %表示の小数桁数
      # 合計と突き合わせるときの許容乖離1割（貸借合計・固定資産の内訳合計など）。
      # 超えたら「未対応の様式か取込不良」とみなして描画しない。
      # 誤ったグラフを出すより出さない方がよい、という安全側の判断
      TOLERANCE = 0.1

      # 「描けない」の共通文言。個別の理由を説明できる形式（ifrs_summaryなど）だけ独自文言を使う
      NO_DATA_NOTE = "データがない、または表示対応していないデータです。".freeze

      # fiscal_year_end_date: 決算日（Date）。説明文を年度で分ける形式だけが使う。分からなければnil
      def initialize(items, fiscal_year_end_date: nil)
        @items = items # {item_code => amount} (Disclosure::FinancialStatement#items_hash)
        @fiscal_year_end_date = fiscal_year_end_date
      end

      # 描くグラフが、保存した科目どうしの式を端数の範囲で満たさないときの、式に使った金額（{科目コード => 金額}）。
      # 取込のときの照合（Ingestion::Reconciliation）がSentryへの警告に使う。式どおりに描くか、描かないときはnil。
      # 貸借2本で描くBS（two_sided_chart）は、描いた借方の科目の合計＝資産合計、資産合計＝負債合計＋純資産合計 を照合する。
      # ほかのグラフは、描き方に合わせて各Builderが上書きする
      def mismatch
        @balance_mismatch = nil
        build
        @balance_mismatch
      end

      private
        def val(code) = @items[code]

        # 保存した科目どうしの式が端数の範囲で成り立つか。differenceは式の左辺と右辺の差、codesは式に使った科目。
        # 端数を持たない入力（精度の分からない科目）では、差が0のときだけ成り立つとみなす
        def balanced?(difference, codes)
          errors = @items.respond_to?(:rounding_errors) ? @items.rounding_errors.values_at(*codes) : codes.map { nil }
          FinancialStatements::RoundingRange.within?(difference, errors)
        end

        def no_data_note(statement_label) = "#{statement_label}: #{NO_DATA_NOTE}"

        # 比率は%値（0-100）。truncate（切り捨て）を使う理由: 四捨五入だと内訳の合計が
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
        # - specs: [key, label, item_code or 金額, color_role] の配列。金額nilの科目はスキップ
        # - equity(資本・純資産)が負なら3本目バー（spacer + 資本のマイナス表示）
        # - 貸借合計の乖離がTOLERANCE超なら描画不可
        # 債務超過表示・貸借検証は形式によらず同じ問題なので、ここに1回だけ実装する
        # （形式別Builderに書かせない = 新形式追加時にこのロジックの再実装漏れが起きない）
        def two_sided_chart(debit_specs:, credit_specs:, equity:, equity_label:, base:, unrenderable_note:)
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
                                                                     within_tolerance?(liabilities_total, -equity)
            debit = []
            base = liabilities_total
            credit = build_segments(credit_specs, base)
          elsif !within_tolerance?(debit_total, credit_total)
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
              seg("spacer", "", spacer_amount, "spacer", base: nil), # base:nil → ratio非表示
              # 債務超過でも色はequityのまま（負であることはラベル・ツールチップの負値で伝える）
              seg("equity", equity_label, -equity, "equity", base: base, signed: equity)
            ])
          else
            bars << Bar.new(label: "貸方",
                            segments: credit + [ seg("equity", equity_label, equity, "equity", base: base) ])
          end
          @balance_mismatch = balance_mismatch(debit_specs, debit)
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
          return if checks.all? { |difference, codes| balanced?(difference, codes) }
          (debit_codes + %w[bs.assets bs.liabilities bs.equity]).to_h { |code| [ code, val(code) ] }.compact
        end

        def build_segments(specs, base)
          specs.filter_map do |key, label, code_or_value, role|
            value = code_or_value.is_a?(String) ? val(code_or_value) : code_or_value
            next if value.nil?
            seg(key, label, value, role, base: base)
          end
        end

        # base（乖離率の分母になる側）に対して value が TOLERANCE 以内か
        def within_tolerance?(base, value)
          return false if base.zero?
          (value - base).abs <= base * TOLERANCE
        end
    end
  end
end
