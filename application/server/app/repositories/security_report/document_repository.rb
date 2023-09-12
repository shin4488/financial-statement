class SecurityReport::DocumentRepository
  def initialize(date:)
    uri = URI("https://disclosure.edinet-fsa.go.jp/api/v1/documents.json")
    queries = { :date => date, :type => 2 }
    uri.query = URI.encode_www_form(queries)
    document_list_response = Net::HTTP.get(uri)
    @response = JSON.parse(document_list_response)
  end

  def document_ids
    document_results = @response["results"]
    return [] if document_results.nil?

    document_results.map { |document_result|
      # 上場会社の有価証券報告書のみを処理するため、それ以外のドキュメントは扱わない
      next if document_result["secCode"].nil? || document_result["docTypeCode"] != "120"

      Rails.logger.info "#{document_result["docID"]} #{document_result["filerName"].tr('０-９ａ-ｚＡ-Ｚ　＆','0-9a-zA-Z &')}"
      document_result["docID"].to_s
    }.reject(&:nil?)
  end
end
