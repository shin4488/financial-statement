require "rails_helper"

# 連結初年度で、その期の子会社の損益を連結しない有報は、連結貸借対照表だけを作り、その期の損益・CFを単体で開示する。
# 取込からAPIまで通し、連結のBSと単体のPLを組み合わせず、単体の値をそろえて返すことを確かめる。
# 期待値は有報の単体の本表の金額と、提出会社の経営指標等の自己資本利益率
RSpec.describe "連結に貸借対照表だけがある有報（実XBRL）" do
  def ingest(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      UseCases::IngestReport.new(client: FixtureEdinetClient.new).call(doc_id: doc_id, work_dir: work_dir)
    end
  end

  def listed_report
    result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
      query { financialReports(limit: 1, offset: 0) {
        consolidationType
        balanceSheet { renderable } profitLoss { renderable } cashFlow { renderable }
        financialIndicators {
          roe { value status source } roa { status } netProfitMargin { status } assetTurnover { status } financialLeverage { status }
        }
      } }
    GRAPHQL
    expect(result["errors"]).to be_nil
    result.dig("data", "financialReports", 0)
  end

  {
    "S100Z8TU" => [ "シルバーライフ 2026年7月期（子会社のみなし取得日を期末にした）", 825_681_000, 6_972_111_000, 7_627_669_000, 0.1131 ],
    "S100QBCW" => [ "クックビズ 2022年11月期（子会社の決算日がまだ来ていない）", 161_893_000, 758_755_000, 1_039_161_000, 0.180 ]
  }.each do |doc_id, (name, profit, equity_begin, equity_end, disclosed_roe)|
    it "#{name}: 単体を主にし、BS・PL・CFと指標を単体の値で返す。連結の貸借対照表も保存する" do
      ingest(doc_id)
      report = listed_report
      expected_roe = profit / ((equity_begin + equity_end) / 2.to_d)

      aggregate_failures do
        expect(Disclosure::FinancialStatement.where(is_primary: true).pluck(:consolidation_type)).to eq [ "non_consolidated" ]
        expect(Disclosure::FinancialStatement.find_by!(consolidation_type: :consolidated).amounts.to_h).to have_key("bs.assets")
        expect(report.fetch("consolidationType")).to eq "non_consolidated"
        expect(report.values_at("balanceSheet", "profitLoss", "cashFlow").map { |chart| chart.fetch("renderable") }).to eq [ true, true, true ]
        indicators = report.fetch("financialIndicators")
        expect(indicators.fetch("roe")).to include("status" => "AVAILABLE", "source" => "CALCULATED")
        expect(indicators.dig("roe", "value")).to be_within(1e-12).of(expected_roe.to_f)
        expect(indicators.dig("roe", "value")).to be_within(0.0005).of(disclosed_roe)
        expect(indicators.except("roe").values.map { |metric| metric.fetch("status") }).to all(eq "AVAILABLE")
      end
    end
  end
end
