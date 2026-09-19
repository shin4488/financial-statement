require "rails_helper"

RSpec.describe "売上高を取得できない実有報の財務指標" do
  # 銀行・日本基準の保険は経常収益を売上高に読み替えない。
  # スカイマーク・東京海上HDは本表とサマリの収益が企業拡張タグだけに存在する。
  %w[S100YJQO S100YD29 S100YRPF S100YLS8].each do |doc_id|
    it "#{doc_id} は売上関連の欠損があってもROE・ROA・レバレッジを返す", :aggregate_failures do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: dir)
      end
      fs = Disclosure::Report.find_by!(edinet_document_id: doc_id).primary_financial_statement
      expect(fs.items_hash["pl.revenue"]).to be_nil

      result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
        query { financialReports(limit: 1, offset: 0) { financialIndicators {
          roe { value status source } roa { value status }
          netProfitMargin { value status } assetTurnover { value status } financialLeverage { value status }
        } } }
      GRAPHQL
      expect(result["errors"]).to be_nil
      metrics = result.dig("data", "financialReports", 0, "financialIndicators")
      %w[roe roa financialLeverage].each do |name|
        expect(metrics.fetch(name)).to include("status" => "AVAILABLE", "value" => a_kind_of(Numeric))
      end
      expect(metrics.fetch("roe").fetch("source")).to eq "CALCULATED"
      %w[netProfitMargin assetTurnover].each do |name|
        expect(metrics.fetch(name)).to eq("status" => "MISSING_DATA", "value" => nil)
      end
    end
  end
end
