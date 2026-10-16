require "rails_helper"

RSpec.describe DailyIngestionJob do
  include ActiveSupport::Testing::TimeHelpers

  it "引数なしで実行すると、日本時間の前日に提出された書類の一覧だけを取得する" do
    list = stub_request(:get, %r{documents\.json})
      .to_return(status: 200, body: { "results" => [] }.to_json)

    # 日本時間2:00はUTCでは前日の17:00のため、前日をどちらの時刻で決めるかで日付が変わる
    travel_to(Time.zone.local(2026, 6, 21, 2, 0)) { described_class.perform_now }

    expect(list).to have_been_requested.once
    expect(a_request(:get, %r{documents\.json}).with(query: hash_including("date" => "2026-06-20", "type" => "2")))
      .to have_been_made.once
  end

  it "EDINETへの書類の取得ごとに本番の間隔（1秒）を待ち、取得に失敗した書類の後も待つ" do
    results = [
      { "docID" => "S1000001", "secCode" => "72030", "filerName" => "取得に失敗する会社", "docTypeCode" => "120" },
      { "docID" => "S1000002", "secCode" => "45020", "filerName" => "取得できる会社", "docTypeCode" => "120" }
    ]
    stub_request(:get, %r{documents\.json}).with(query: hash_including("date" => "2026-06-20"))
      .to_return(status: 200, body: { "results" => results.map { |r| { "ordinanceCode" => "010" }.merge(r) } }.to_json)
    events = []
    # ジョブは待ち方を渡さずに取込を作るため、既定の待ち方（Kernel.sleep）を差し替えて、待った秒数を記録する
    allow(Kernel).to receive(:sleep) { |seconds| events << [ :sleep, seconds ] }
    stub_request(:get, %r{documents/S1000001}).to_return do
      events << [ :download, "S1000001" ]
      { status: 500 }
    end
    stub_request(:get, %r{documents/S1000002}).to_return do
      events << [ :download, "S1000002" ]
      zip = Zip::OutputStream.write_buffer do |stream|
        stream.put_next_entry("S1000002/PublicDoc/0000000_header.xbrl")
        stream.write(synthetic_xbrl_xml(dei: { stock_code: "45020" }))
      end
      { status: 200, body: zip.string }
    end
    allow(Sentry).to receive(:capture_exception)

    travel_to(Time.zone.local(2026, 6, 21, 2, 0)) { described_class.perform_now }

    expect(events).to eq [ [ :download, "S1000001" ], [ :sleep, 1 ], [ :download, "S1000002" ], [ :sleep, 1 ] ]
  end
end
