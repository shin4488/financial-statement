module UseCases
  # docIDを指定して有報を上から順に取り込む（rakeの経路）。結果はrakeの実行者が読む標準出力に出す。
  # 一覧を経由しないため、一覧の証券コードとの照合はしない
  class IngestDocuments
    def initialize(client: Edinet::Client.new, sleeper: Kernel.method(:sleep))
      @client, @sleeper = client, sleeper
    end

    def call(doc_ids)
      ingester = Ingestion::ReportIngester.new(client: @client)
      Dir.mktmpdir("edinet") do |work_dir|
        SequentialRunner.each(doc_ids, sleeper: @sleeper,
                              on_success: method(:record_success), on_failure: method(:record_failure)) do |doc_id|
          ingester.ingest(doc_id: doc_id, work_dir: work_dir)
        end
      end
    end

    private

    def record_success(doc_id) = puts("ingested #{doc_id}")

    def record_failure(doc_id, error)
      puts "ingest failed #{doc_id}: #{error.message}"
      Sentry.capture_exception(error)
    end
  end
end
