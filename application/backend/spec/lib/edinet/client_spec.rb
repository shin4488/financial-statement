require "rails_helper"

# EDINET APIとの境界。HTTPはWebMockで代替する（rails_helperで実接続は遮断済み）
RSpec.describe Edinet::Client do
  subject(:client) { described_class.new }

  describe "#list_annual_reports" do
    def stub_list(results)
      stub_request(:get, %r{api\.edinet-fsa\.go\.jp/api/v2/documents\.json})
        .to_return(status: 200, body: { "results" => results }.to_json)
    end

    it "上場企業（証券コードあり）の有報・訂正有報だけを返す" do
      stub_list([
        { "docID" => "S1000001", "secCode" => "72030", "filerName" => "対象の有報", "docTypeCode" => "120" },
        { "docID" => "S1000002", "secCode" => "45020", "filerName" => "対象の訂正有報", "docTypeCode" => "130" },
        { "docID" => "S1000003", "secCode" => nil, "filerName" => "非上場（投資信託等）", "docTypeCode" => "120" },
        { "docID" => "S1000004", "secCode" => "99990", "filerName" => "四半期報告書など", "docTypeCode" => "140" }
      ])
      metas = client.list_annual_reports(date: Date.new(2026, 6, 20))
      expect(metas.map { |m| [ m.doc_id, m.sec_code, m.filer_name ] })
        .to eq [ [ "S1000001", "72030", "対象の有報" ], [ "S1000002", "45020", "対象の訂正有報" ] ]
    end

    it "HTTPエラーのときは本文をJSONとして読まず、ステータスつきで失敗する" do
      stub_request(:get, %r{documents\.json}).to_return(status: 403, body: "<html>error page</html>")
      expect { client.list_annual_reports(date: Date.new(2026, 6, 20)) }
        .to raise_error(/EDINET documents\.json failed: 403/)
    end
  end

  describe "#download_xbrl" do
    def zip_body(entries)
      Zip::OutputStream.write_buffer do |zip|
        entries.each do |path, content|
          zip.put_next_entry(path)
          zip.write(content)
        end
      end.string
    end

    def stub_download(doc_id, body)
      stub_request(:get, %r{api\.edinet-fsa\.go\.jp/api/v2/documents/#{doc_id}})
        .to_return(status: 200, body: body)
    end

    it "PublicDoc配下のXBRLインスタンスを展開してパスを返し、zipは残さない" do
      stub_download("S1000001", zip_body(
        "S1000001/PublicDoc/0000000_header.xbrl" => "<xbrl>本文</xbrl>",
        "S1000001/AuditDoc/audit.xbrl" => "<xbrl>監査報告書</xbrl>"))
      Dir.mktmpdir do |work_dir|
        path = client.download_xbrl(doc_id: "S1000001", work_dir: work_dir)
        aggregate_failures do
          expect(File.read(path)).to eq "<xbrl>本文</xbrl>"
          expect(Dir.glob(File.join(work_dir, "*.zip"))).to be_empty
        end
      end
    end

    it "本文XBRLを含まない書類（一部の訂正有報）はnilを返す" do
      stub_download("S1000001", zip_body("S1000001/PublicDoc/0000000_header.xsd" => "スキーマのみ"))
      Dir.mktmpdir do |work_dir|
        expect(client.download_xbrl(doc_id: "S1000001", work_dir: work_dir)).to be_nil
      end
    end

    it "docIDの形式が不正なら、リクエスト前に入力ミスと分かるメッセージで失敗する" do
      Dir.mktmpdir do |work_dir|
        expect { client.download_xbrl(doc_id: "S100YB5x", work_dir: work_dir) }
          .to raise_error(ArgumentError, /invalid docID/)
      end
    end
  end
end
