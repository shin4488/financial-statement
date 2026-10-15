module Ingestion
  # 1有報の取込の手順は UseCases::IngestReport が持つ。ここはそれを呼ぶだけの入口
  class ReportIngester
    def initialize(client: Edinet::Client.new,
                   dei_extractor: DeiExtractor.new,
                   detector: FormatDetector.new)
      @ingest_report = UseCases::IngestReport.new(client: client, dei_extractor: dei_extractor, detector: detector)
    end

    def ingest(doc_id:, work_dir:, expected_sec_code: nil)
      @ingest_report.call(doc_id: doc_id, work_dir: work_dir, expected_sec_code: expected_sec_code)
    end
  end
end
