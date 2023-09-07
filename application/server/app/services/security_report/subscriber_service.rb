require "net/http"
require "open-uri"

class SecurityReport::SubscriberService
  include Sidekiq::Worker

  @@project_root_path = Rails.root.join("security_reports").freeze

  class << self
    def perform(from_date:, end_date: Date.today)
      FileUtils.mkdir_p(@@project_root_path)

      # zipファイルパスの生成
      document_id_security_report_zip_paths = generate_security_report_zip_path(from_date: from_date, end_date: end_date)
      # zipファイルのダウンロード・保存
      security_report_xbrl_paths = document_id_security_report_zip_paths.map do |document_id, zip_path|
        uri = URI("https://disclosure.edinet-fsa.go.jp/api/v1/documents/#{document_id}")
        queries = { :type => 1 }
        uri.query = URI.encode_www_form(queries)
        uri.open do |file|
          # https://docs.ruby-lang.org/ja/latest/method/Kernel/m/open.html
          File.open(zip_path, "w+b") do |out|
            out.write(file.read)
          end
        end

        # zipファイルの展開
        Zip::File.open(zip_path) do |zip_file|
          # zipファイルから、財務データの存在するxbrlファイルのみを残す
          entry = zip_file.glob("*/PublicDoc/*.xbrl").first
          xbrl_directory_path = File.join(@@project_root_path, document_id)
          # https://qiita.com/wjhmks1219/items/f52f6cbc8785346154e7
          FileUtils.mkpath(xbrl_directory_path)
          xbrl_file_path = File.join(xbrl_directory_path, File.basename(entry.name))
          zip_file.extract(entry, xbrl_file_path) unless File.exist?(xbrl_file_path)
          # 展開したzipは削除
          FileUtils.rm(zip_path)
          xbrl_file_path
        end
      end

      [document_id_security_report_zip_paths, security_report_xbrl_paths]
    end

    def generate_security_report_zip_path(from_date:, end_date:)
      uri = URI("https://disclosure.edinet-fsa.go.jp/api/v1/documents.json")
      queries = { :date => from_date, :type => 2 }
      uri.query = URI.encode_www_form(queries)
      document_list_response = Net::HTTP.get(uri)
      document_list_response_body = JSON.parse(document_list_response)
      document_results = document_list_response_body["results"]
      document_results.map { |document_result|
        # 上場会社の有価証券報告書のみを処理するため、それ以外のドキュメントは扱わない
        next if document_result["secCode"].nil? || document_result["docTypeCode"] != "120"

        puts "#{document_result["docID"]} #{document_result["filerName"].tr('０-９ａ-ｚＡ-Ｚ　＆','0-9a-zA-Z &')}"
        document_id = document_result["docID"]
        zip_path = File.join(@@project_root_path, "#{document_id}.zip").to_s
        [document_id, zip_path]
      }.reject(&:nil?).to_h
    end
  end
end
