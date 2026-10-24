require "rails_helper"

RSpec.describe UseCases::IngestionNotices do
  describe ".build" do
    {
      accounting_standard_unknown: [ { doc_id: "S0000001" }, "accounting standard unknown: S0000001", :warning ],
      invalid_edinet_code: [ { doc_id: "S0000001", edinet_code: "不正な値" },
                             'invalid edinet code in DEI: S0000001 ("不正な値")', :error ],
      sec_code_mismatch: [ { doc_id: "S0000001", expected_sec_code: "72030", stock_code: "45020" },
                           "sec code mismatch: S0000001 (list=72030 dei=45020)", :error ],
      skip_empty_extraction: [ { doc_id: "S0000001", consolidation_type: :non_consolidated },
                               "skip empty extraction for existing statement: S0000001 (non_consolidated)", :warning ],
      missing_assets: [ { doc_id: "S0000001", presentation_format: "jgaap_general" },
                        "primary statement missing bs.assets: S0000001 (jgaap_general)", :warning ]
    }.each do |kind, (values, message, level)|
      it "#{kind}: 書類ごとの値を文言に含め、文言の「:」より前をfingerprintにし、付加情報は渡さない" do
        notice = described_class.build(kind, **values)

        aggregate_failures do
          expect(notice.message).to eq message
          expect(notice.options).to eq(level: level, fingerprint: [ message.split(":").first ])
        end
      end
    end

    it "書類ごとの値がnilなら、空として文言に埋め込む" do
      notice = described_class.build(:sec_code_mismatch, doc_id: "S0000001", expected_sec_code: "45020", stock_code: nil)
      expect(notice.message).to eq "sec code mismatch: S0000001 (list=45020 dei=)"
    end

    {
      revenue_mismatch: "revenue does not match summary of business results",
      revenue_missing: "revenue missing although summary of business results has revenue",
      profit_loss_mismatch: "profit and loss chart expenses do not reconcile",
      balance_sheet_mismatch: "balance sheet chart does not reconcile with totals",
      cash_flow_mismatch: "cash flow does not reconcile with closing balance"
    }.each do |kind, message|
      it "#{kind}: 文言を固定してfingerprintにし、書類ID・連結区分（文字列）・形式・照合に使った金額を付加情報にする" do
        notice = described_class.build(kind, doc_id: "S0000001", consolidation_type: :consolidated,
                                             presentation_format: "ifrs_classified", amounts: { "pl.revenue" => 100 })

        aggregate_failures do
          expect(notice.message).to eq message
          expect(notice.options).to eq(
            level: :warning, fingerprint: [ message ],
            extra: { doc_id: "S0000001", consolidation_type: "consolidated", presentation_format: "ifrs_classified",
                     amounts: { "pl.revenue" => 100 } })
          expect(notice.options[:extra].keys).to eq %i[doc_id consolidation_type presentation_format amounts]
        end
      end
    end

    it "取込で送るメッセージの通知は、上の10種類だけ" do
      expect(described_class::KINDS.keys.map { |kind| described_class.text(kind) }).to contain_exactly(
        "accounting standard unknown", "invalid edinet code in DEI", "sec code mismatch",
        "skip empty extraction for existing statement", "primary statement missing bs.assets",
        "revenue does not match summary of business results", "revenue missing although summary of business results has revenue",
        "profit and loss chart expenses do not reconcile", "balance sheet chart does not reconcile with totals",
        "cash flow does not reconcile with closing balance")
    end

    it "定義にない種類は KeyError にする" do
      expect { described_class.build(:unknown, doc_id: "S0000001") }.to raise_error(KeyError)
    end
  end
end
