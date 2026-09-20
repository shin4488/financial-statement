class AnalyticsController < ApplicationController
  # 前段nginxの /api/ レート制限が適用される。認証情報・リクエスト本文をログに残さない。
  def create
    return head :unsupported_media_type unless request.media_type == "application/json"
    return head :payload_too_large if request.content_length.to_i > 2048

    body = request.body.read(2049)
    return head :payload_too_large if body.bytesize > 2048

    Analytics::ExtensionEvent.new(JSON.parse(body)).deliver
    head :no_content
  rescue JSON::ParserError, Analytics::ExtensionEvent::Invalid
    head :bad_request
  rescue Analytics::ExtensionEvent::Unavailable
    head :service_unavailable
  end
end
