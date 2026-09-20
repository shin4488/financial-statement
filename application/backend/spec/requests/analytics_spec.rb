require "rails_helper"

RSpec.describe "Extension analytics", type: :request do
  let(:payload) do
    { client_id: "12345678-1234-4234-8234-123456789012", session_id: 1_789_870_000,
      name: "report_result", params: { result_status: "success", result_count: 2,
      site_domain_name: "kabutan.jp", extension_version: "1.4.0", engagement_time_msec: 120 } }
  end
  let(:endpoint) { "https://www.google-analytics.com/mp/collect?measurement_id=G-TEST123456&api_secret=test-secret" }

  before do
    host! ENV.fetch("SERVER_HOST_NAME", "www.example.com")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("EXTENSION_GA_MEASUREMENT_ID").and_return("G-TEST123456")
    allow(ENV).to receive(:[]).with("EXTENSION_GA_API_SECRET").and_return("test-secret")
  end

  it "forwards only the bounded event to the fixed GA destination" do
    stub = stub_request(:post, endpoint).with do |req|
      body = JSON.parse(req.body)
      expect(body.keys).to contain_exactly("client_id", "consent", "events")
      expect(body["client_id"]).to match(/\A\d+\.\d+\z/)
      expect(body["client_id"]).not_to eq(payload[:client_id])
      expect(body["events"][0]).to eq({ "name" => "report_result", "params" => {
        "result_status" => "success", "result_count" => 2, "site_domain_name" => "kabutan.jp",
        "extension_version" => "1.4.0", "engagement_time_msec" => 120,
        "session_id" => 1_789_870_000, "analytics_version" => "2"
      } })
      expect(body["consent"].values).to eq(%w[DENIED DENIED])
      true
    end.to_return(status: 204)
    post "/analytics/extension", params: payload, as: :json
    expect(response).to have_http_status(:no_content)
    expect(stub).to have_been_requested.once
  end

  it "keeps the GA client identifier stable across sessions and UUID casing" do
    clients = []
    stub_request(:post, endpoint).with { |req| clients << JSON.parse(req.body)["client_id"]; true }.to_return(status: 204)
    post "/analytics/extension", params: payload, as: :json
    post "/analytics/extension", params: payload.merge(client_id: payload[:client_id].upcase, session_id: payload[:session_id] + 1), as: :json
    expect(clients.size).to eq(2)
    expect(clients.uniq.size).to eq(1)
  end

  it "rejects arbitrary events, destinations, identifiers, and personal data without forwarding" do
    invalid = [
      payload.merge(name: "purchase"), payload.merge(client_id: "person@example.com"),
      payload.merge(session_id: -1), payload.merge(measurement_id: "G-OTHER"),
      payload.merge(params: payload[:params].merge(page_location: "https://example.com/private")),
      payload.merge(params: payload[:params].merge(site_domain_name: "private.example")),
      payload.merge(params: payload[:params].merge(result_count: 1001)),
      payload.merge(params: payload[:params].merge(engagement_time_msec: "100")),
      payload.merge(params: payload[:params].except(:engagement_time_msec)),
      payload.merge(params: payload[:params].merge(extension_version: "private"))
    ]
    invalid.each do |body|
      post "/analytics/extension", params: body, as: :json
      expect(response).to have_http_status(:bad_request)
    end
    expect(a_request(:post, /google-analytics/)).not_to have_been_made
  end

  it "bounds request size and requires JSON" do
    post "/analytics/extension", params: "x" * 2049, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:payload_too_large)
    post "/analytics/extension", params: payload
    expect(response).to have_http_status(:unsupported_media_type)
    expect(a_request(:post, /google-analytics/)).not_to have_been_made
  end

  it "fails closed when deployment configuration is missing" do
    allow(ENV).to receive(:[]).with("EXTENSION_GA_API_SECRET").and_return(nil)
    post "/analytics/extension", params: payload, as: :json
    expect(response).to have_http_status(:service_unavailable)
    expect(a_request(:post, /google-analytics/)).not_to have_been_made
  end

  it "contains upstream outages without retries or leaking secret URLs" do
    stub = stub_request(:post, endpoint).to_timeout
    post "/analytics/extension", params: payload, as: :json
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to be_empty
    expect(stub).to have_been_requested.once
  end
end
