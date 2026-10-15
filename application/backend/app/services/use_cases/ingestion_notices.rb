module UseCases
  # 取込で送るメッセージの通知の種類（文言の固定部分・level・fingerprint）。
  # fingerprintは文言の固定部分にし、送った箇所でなく通知の種類ごとに1つのissueにまとめる（書類ごとに変わる値を入れると、書類ごとにissueが分かれる）
  module IngestionNotices
    # 1件の通知。値のない fingerprint・extra は nil で持ち、Sentryへのキーワード引数に含めない
    Notice = Data.define(:message, :level, :fingerprint, :extra) do
      def options = { level: level, fingerprint: fingerprint, extra: extra }.compact
    end

    # 書類ごとの値を「固定部分: 値」の形で文言に含める種類。detail は値から「: 」より後ろを作る
    Described = Data.define(:text, :level, :detail) do
      def build(**values) = Notice.new(message: "#{text}: #{detail.call(**values)}", level: level, fingerprint: [ text ], extra: nil)
    end

    # 照合の警告。文言は照合の種類ごとに固定し、書類ごとの値と照合に使った金額は付加情報にする
    Mismatch = Data.define(:text) do
      def build(doc_id:, consolidation_type:, presentation_format:, amounts:)
        Notice.new(message: text, level: :warning, fingerprint: [ text ],
                   extra: { doc_id: doc_id, consolidation_type: consolidation_type.to_s,
                            presentation_format: presentation_format, amounts: amounts })
      end
    end
    private_constant :Described, :Mismatch

    KINDS = {
      # 対象確認
      accounting_standard_unknown: Described.new("accounting standard unknown", :warning, ->(doc_id:) { doc_id }),
      invalid_edinet_code: Described.new("invalid edinet code in DEI", :error,
                                         ->(doc_id:, edinet_code:) { "#{doc_id} (#{edinet_code.inspect})" }),
      sec_code_mismatch: Described.new("sec code mismatch", :error,
                                       ->(doc_id:, expected_sec_code:, stock_code:) { "#{doc_id} (list=#{expected_sec_code} dei=#{stock_code})" }),
      # 保存
      skip_empty_extraction: Described.new("skip empty extraction for existing statement", :warning,
                                           ->(doc_id:, consolidation_type:) { "#{doc_id} (#{consolidation_type})" }),
      # 点検
      missing_assets: Described.new("primary statement missing bs.assets", :warning,
                                    ->(doc_id:, presentation_format:) { "#{doc_id} (#{presentation_format})" }),
      revenue_mismatch: Mismatch.new("revenue does not match summary of business results".freeze),
      revenue_missing: Mismatch.new("revenue missing although summary of business results has revenue".freeze),
      # 描いたPLの費用が、保存した科目どうしの式を端数の範囲で満たさない（タグで費用を説明できない）。
      # 式は描き方で違い、グラフ作成処理が決める（日本基準は費用・営業利益と売上、IFRSは積まなかった営業費用と売上原価・販管費）
      profit_loss_mismatch: Mismatch.new("profit and loss chart expenses do not reconcile".freeze),
      # 描いたBSで、借方の科目の合計が資産合計と、または資産合計が負債合計＋純資産合計と、端数の範囲で一致しない
      balance_sheet_mismatch: Mismatch.new("balance sheet chart does not reconcile with totals".freeze),
      # 期首残＋各CF＋換算差額など＝期末残が、行がない項目を0とみなしても端数の範囲で成り立たない
      cash_flow_mismatch: Mismatch.new("cash flow does not reconcile with closing balance".freeze)
    }.freeze

    module_function

    def build(kind, **values) = KINDS.fetch(kind).build(**values)

    # 文言の固定部分
    def text(kind) = KINDS.fetch(kind).text
  end
end
