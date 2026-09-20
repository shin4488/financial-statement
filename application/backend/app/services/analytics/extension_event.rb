require "net/http"
require "json"

module Analytics
  # 公開API。計測先・イベント・値を固定し、任意のMPプロキシにしない。
  # IP、閲覧URL、証券コード、例外本文はGoogleに送信しない。
  class ExtensionEvent
    class Invalid < StandardError; end
    class Unavailable < StandardError; end

    EVENTS = %w[popup_open report_result analysis_interaction outbound_click].freeze
    DOMAINS = %w[www.buffett-code.com minkabu.jp kabutan.jp www.rakuten-sec.co.jp member.rakuten-sec.co.jp shikiho.toyokeizai.net finance.yahoo.co.jp unknown].freeze
    PARAMS = {
      "site_domain_name" => DOMAINS,
      "result_status" => %w[success empty error],
      "interaction_type" => %w[chart_navigation autoplay_on autoplay_off],
      "chart_type" => %w[bs pl cf indicators],
      "link_domain" => %w[kabutan.jp investee.info]
    }.freeze
    NUMBERS = { "result_count" => 0..1000, "unavailable_count" => 0..1000, "engagement_time_msec" => 1..3_600_000 }.freeze
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def initialize(input)
      raise Invalid unless input.is_a?(Hash) && (input.keys - %w[client_id session_id name params]).empty?
      raise Invalid unless input["client_id"].is_a?(String) && input["client_id"].match?(UUID)
      raise Invalid unless input["session_id"].is_a?(Integer) && input["session_id"].between?(1, 9_999_999_999)
      raise Invalid unless EVENTS.include?(input["name"])
      params = input["params"]
      raise Invalid unless params.is_a?(Hash)
      params.each do |key, value|
        valid = if PARAMS.key?(key)
          PARAMS[key].include?(value)
        elsif NUMBERS.key?(key)
          value.is_a?(Integer) && NUMBERS[key].cover?(value)
        elsif key == "extension_version"
          value.is_a?(String) && value.match?(/\A\d{1,4}\.\d{1,4}\.\d{1,4}\z/)
        else
          false
        end
        raise Invalid unless valid
      end
      raise Invalid unless params.key?("engagement_time_msec") && params.key?("extension_version")

      @payload = {
        client_id: input["client_id"],
        consent: { ad_user_data: "DENIED", ad_personalization: "DENIED" },
        events: [ { name: input["name"], params: params.merge("session_id" => input["session_id"], "analytics_version" => "2") } ]
      }
    end

    def deliver
      measurement_id = ENV["EXTENSION_GA_MEASUREMENT_ID"].to_s
      secret = ENV["EXTENSION_GA_API_SECRET"].to_s
      raise Unavailable unless measurement_id.match?(/\AG-[A-Z0-9]+\z/) && !secret.empty?

      uri = URI("https://www.google-analytics.com/mp/collect")
      uri.query = URI.encode_www_form(measurement_id: measurement_id, api_secret: secret)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 2
      http.write_timeout = 2
      http.max_retries = 0
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(@payload)
      response = http.request(request)
      raise Unavailable unless response.is_a?(Net::HTTPSuccess)
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError
      # 例外本文にはURL（秘密キー）が入る可能性がある。ログ・Sentryへ渡さない。
      raise Unavailable
    end
  end
end
