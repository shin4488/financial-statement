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
end
