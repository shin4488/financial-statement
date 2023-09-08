require "net/http"
require "open-uri"

class SecurityReport::SubscriberService
  include Sidekiq::Worker

  REPORT_DIR_PATH = Rails.root.join("security_reports").freeze

  class << self
    def perform(from_date:, end_date: Date.today)
      FileUtils.mkdir_p(REPORT_DIR_PATH)

      # zipファイルパスの生成
      document_id_security_report_zip_paths = generate_security_report_zip_path(from_date:, end_date:)

      # zipファイルのダウンロード・保存
      security_report_result = document_id_security_report_zip_paths.map do |document_id, zip_path|
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
          # zipファイルから、財務データの存在するxbrlファイルのみを処理する、ファイルがなかったら財務データがないものとして登録しない
          entry = zip_file.glob("*/PublicDoc/*.xbrl").first
          next if entry.nil?

          xbrl_directory_path = File.join(REPORT_DIR_PATH, document_id)
          # https://qiita.com/wjhmks1219/items/f52f6cbc8785346154e7
          FileUtils.mkpath(xbrl_directory_path)
          xbrl_file_path = File.join(xbrl_directory_path, File.basename(entry.name))
          zip_file.extract(entry, xbrl_file_path) unless File.exist?(xbrl_file_path)
          # 展開したzipは削除
          FileUtils.rm(zip_path)

          security_report = SecurityReport::ReaderRepository.new(xbrl_file_path).read
          [xbrl_file_path, security_report]
        end
      end.reject(&:nil?)

      security_report_result
    end

    private
      def generate_security_report_zip_path(from_date:, end_date:)
        document_repository = SecurityReport::DocumentRepository.new(from_date: from_date, end_date: end_date)
        document_ids = document_repository.document_ids
        document_ids.map { |document_id|
          zip_path = File.join(REPORT_DIR_PATH, "#{document_id}.zip").to_s
          [document_id, zip_path]
        }.to_h
      end
  end
end
