require "rails_helper"

RSpec.describe Ingestion::DocumentScreening do
  let(:company_class) { Struct.new(:edinet_code, :stock_code) }
  let(:report_class) { Struct.new(:company, :fiscal_year_start_date, :fiscal_year_end_date) }
  let(:lookups) { [] }

  def dei(**overrides)
    Ingestion::DeiExtractor::Result.new(
      edinet_code: "E00001", stock_code: "45020", fund_code: nil, accounting_standard: "japan_gaap",
      fiscal_year_start_date: "2025-04-01", fiscal_year_end_date: "2026-03-31", **overrides)
  end

  # 同じ書類IDの既存書類。DEIと同じ企業・会計期間のもの
  def known_report(edinet_code: "E00001", stock_code: "45020", start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31))
    report_class.new(company_class.new(edinet_code, stock_code), start_date, end_date)
  end

  def check(dei, expected_sec_code: nil, report: nil)
    described_class.check(dei, doc_id: "S0000001", expected_sec_code: expected_sec_code,
                               known_report: -> { lookups << :called; report })
  end

  def verdict(action, stock_code, notice_kind = nil, **notice_values)
    described_class::Verdict.new(action: action, stock_code: stock_code, notice_kind: notice_kind, notice_values: notice_values)
  end

  it "DEIの証券コードがあり、一覧の証券コードと一致すれば取り込み、既存書類は引かない" do
    aggregate_failures do
      expect(check(dei, expected_sec_code: "45020")).to eq verdict(:proceed, "45020")
      expect(check(dei)).to eq verdict(:proceed, "45020")
      expect(lookups).to be_empty
    end
  end

  it "ファンドの書類は、ほかの条件より先に表示対象から外す判定にし、通知しない" do
    aggregate_failures do
      expect(check(dei(fund_code: "G15497", stock_code: "", accounting_standard: nil))).to eq verdict(:exclude_fund, nil)
      expect(lookups).to be_empty
    end
  end

  describe "DEIの証券コードが空のとき" do
    it "既存書類と企業・会計期間が一致すれば、企業マスタの証券コードを照合と保存に使い、DEIは書き換えない" do
      screened = dei(stock_code: "")

      aggregate_failures do
        expect(check(screened, report: known_report(stock_code: "45020"))).to eq verdict(:proceed, "45020")
        expect(lookups).to eq [ :called ]
        expect(screened.stock_code).to eq ""
      end
    end

    it "企業マスタにも証券コードがなければ、推測せずにその値（空）のまま取り込む" do
      expect(check(dei(stock_code: nil), report: known_report(stock_code: ""))).to eq verdict(:proceed, "")
    end

    it "補った証券コードを一覧の証券コードと照合し、食い違えば補った値で通知する" do
      aggregate_failures do
        expect(check(dei(stock_code: ""), expected_sec_code: "72030", report: known_report(stock_code: "45020")))
          .to eq verdict(:stop, "45020", :sec_code_mismatch, doc_id: "S0000001", expected_sec_code: "72030", stock_code: "45020")
        expect(check(dei(stock_code: ""), expected_sec_code: "45020", report: known_report(stock_code: "")))
          .to eq verdict(:stop, "", :sec_code_mismatch, doc_id: "S0000001", expected_sec_code: "45020", stock_code: "")
        expect(check(dei(stock_code: ""), expected_sec_code: "45020", report: known_report(stock_code: "45020")))
          .to eq verdict(:proceed, "45020")
      end
    end

    {
      "既存書類がない" => nil,
      "既存書類の企業が違う" => { edinet_code: "E99999" },
      "既存書類の期首が違う" => { start_date: Date.new(2024, 4, 1) },
      "既存書類の期末が違う" => { end_date: Date.new(2025, 3, 31) }
    }.each do |condition, mismatch|
      it "#{condition}ときは、通知せずに取り込まない" do
        report = mismatch && known_report(**mismatch)
        expect(check(dei(stock_code: ""), report: report)).to eq verdict(:stop, nil)
      end
    end
  end

  it "会計基準が分からなければ、警告の通知の種類と値を返して取り込まない" do
    expect(check(dei(accounting_standard: nil, edinet_code: "不正な値")))
      .to eq verdict(:stop, "45020", :accounting_standard_unknown, doc_id: "S0000001")
  end

  [ "不正な値", "e00001", "E0001", "E000001", nil ].each do |edinet_code|
    it "DEIのEDINETコードが英大文字1字と数字5桁でなければ（#{edinet_code.inspect}）、その値を通知の値にして取り込まない" do
      expect(check(dei(edinet_code: edinet_code), expected_sec_code: "72030"))
        .to eq verdict(:stop, "45020", :invalid_edinet_code, doc_id: "S0000001", edinet_code: edinet_code)
    end
  end

  it "一覧の証券コードとDEIの証券コードが食い違えば、両方を通知の値にして取り込まない" do
    expect(check(dei, expected_sec_code: "72030"))
      .to eq verdict(:stop, "45020", :sec_code_mismatch, doc_id: "S0000001", expected_sec_code: "72030", stock_code: "45020")
  end
end
