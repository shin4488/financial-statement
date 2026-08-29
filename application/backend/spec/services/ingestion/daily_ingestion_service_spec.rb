require "rails_helper"

# 日次バッチの核心は「1件の失敗を他に波及させない」こと。
# HTTPをWebMockで代替し、EDINET一覧 → ダウンロード → 保存 まで実経路で検証する
RSpec.describe Ingestion::DailyIngestionService do
  before do
    # 書類間のスロットリング待ちはEDINET実環境向けの挙動なので、テストでは時間を使わない
    allow(described_class).to receive(:sleep)
  end

  def stub_list(date, results)
    stub_request(:get, %r{documents\.json}).with(query: hash_including("date" => date.to_s))
      .to_return(status: 200, body: { "results" => results }.to_json)
  end

  def zip_with_xbrl(doc_id, xml)
    Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("#{doc_id}/PublicDoc/0000000_header.xbrl")
      zip.write(xml)
    end.string
  end

  it "1書類の失敗は記録して次の書類へ進む（他社の取込に波及させない）" do
    date = Date.new(2026, 6, 20)
    stub_list(date, [
      { "docID" => "S1000001", "secCode" => "72030", "filerName" => "取得に失敗する会社", "docTypeCode" => "120" },
      { "docID" => "S1000002", "secCode" => "45020", "filerName" => "取得できる会社", "docTypeCode" => "120" }
    ])
    stub_request(:get, %r{documents/S1000001}).to_return(status: 500)
    stub_request(:get, %r{documents/S1000002})
      .to_return(status: 200, body: zip_with_xbrl("S1000002", synthetic_xbrl_xml(dei: { stock_code: "45020" })))

    expect(Sentry).to receive(:capture_exception).once
    described_class.run(from_date: date, to_date: date)

    expect(Disclosure::Report.sole.edinet_document_id).to eq "S1000002"
  end

  it "一覧取得に失敗した日はスキップし、他の日の取込は続ける" do
    failed_date = Date.new(2026, 6, 20)
    ok_date = Date.new(2026, 6, 21)
    stub_request(:get, %r{documents\.json}).with(query: hash_including("date" => failed_date.to_s))
      .to_return(status: 403, body: "rate limited")
    stub_list(ok_date, [ { "docID" => "S1000002", "secCode" => "45020", "filerName" => "取得できる会社", "docTypeCode" => "120" } ])
    stub_request(:get, %r{documents/S1000002})
      .to_return(status: 200, body: zip_with_xbrl("S1000002", synthetic_xbrl_xml(dei: { stock_code: "45020" })))

    expect(Sentry).to receive(:capture_exception).once
    described_class.run(from_date: failed_date, to_date: ok_date)

    expect(Disclosure::Report.sole.edinet_document_id).to eq "S1000002"
  end
end
