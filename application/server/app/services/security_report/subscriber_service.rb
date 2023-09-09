require "net/http"
require "open-uri"

class SecurityReport::SubscriberService
  include Sidekiq::Worker

  REPORT_DIR_PATH = Rails.root.join("security_reports").freeze

  class << self
    def subscribe(from_date: Time.zone.yesterday, end_date: Time.zone.yesterday)
      FileUtils.remove_entry_secure(REPORT_DIR_PATH) if Dir.exist?(REPORT_DIR_PATH)
      FileUtils.mkdir_p(REPORT_DIR_PATH)

      # zipファイルパスの生成
      document_id_security_report_zip_paths = generate_security_report_zip_path(from_date:, end_date:)

      security_report_result = document_id_security_report_zip_paths.each do |document_id, zip_path|
        # zipファイルのダウンロード・保存
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
        xbrl_file_path = Zip::File.open(zip_path) do |zip_file|
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
          xbrl_file_path
        end

        security_report = SecurityReport::ReaderRepository.new(xbrl_file_path).read
        # 読み取ったxbrlファイルは、以降では使用せずまたディスク容量を不用意に取らないためにも削除する
        FileUtils.remove_entry_secure(File.expand_path("..", xbrl_file_path))
        company_id = create_company(security_report)
        create_security_report(security_report, company_id)
      end

      [Company.all, SecurityReport.all]
    end

    private
      def generate_security_report_zip_path(from_date:, end_date:)
        document_repository = SecurityReport::DocumentRepository.new(date: from_date)
        document_ids = document_repository.document_ids
        document_ids.map { |document_id|
          zip_path = File.join(REPORT_DIR_PATH, "#{document_id}.zip").to_s
          [document_id, zip_path]
        }.to_h
      end

      def create_company(report_company)
        company_result = Company.upsert({
          edinet_code: report_company[:edinet_code],
          stock_code: report_company[:stock_code],
          company_japanese_name: report_company[:company_japanese_name],
          company_english_name: report_company[:company_english_name],
        }, unique_by: :edinet_code)
        company_result.last["id"]
      end

      def create_security_report(security_report, company_id)
        consolidated_statement = security_report[:consolidated_statement]
        non_consolidated_statement = security_report[:non_consolidated_statement]

        # 財務諸表の修正取込も可能とするためにupsertとする
        SecurityReport.upsert({
          # 会計年度の企業情報
          company_id: company_id,
          accounting_standard: security_report[:accounting_standard],
          has_consolidated_financial_statement: security_report[:has_consolidated_financial_statement],
          fiscal_year_start_date: security_report[:fiscal_year_start_date],
          fiscal_year_end_date: security_report[:fiscal_year_end_date],
          consolidated_inductory_code: security_report[:consolidated_inductory_code],
          non_consolidated_inductory_code: security_report[:non_consolidated_inductory_code],
          # 連結財務諸表
          consolidated_current_asset: consolidated_statement[:current_asset],
          consolidated_property_plant_and_equipment: consolidated_statement[:property_plant_and_equipment],
          consolidated_intangible_asset: consolidated_statement[:intangible_asset],
          consolidated_investment_and_other_asset: consolidated_statement[:investment_and_other_asset],
          consolidated_non_current_asset: consolidated_statement[:non_current_asset],
          consolidated_asset: consolidated_statement[:asset],
          consolidated_current_liability: consolidated_statement[:current_liability],
          consolidated_non_current_liability: consolidated_statement[:non_current_liability],
          consolidated_liability: consolidated_statement[:liability],
          consolidated_net_asset: consolidated_statement[:net_asset],
          consolidated_net_sales: consolidated_statement[:net_sales],
          consolidated_cost_of_sales: consolidated_statement[:cost_of_sales],
          consolidated_gross_profit: consolidated_statement[:gross_profit],
          consolidated_selling_general_and_administrative_expense: consolidated_statement[:selling_general_and_administrative_expense],
          consolidated_operating_income: consolidated_statement[:operating_income],
          consolidated_non_operating_income: consolidated_statement[:non_operating_income],
          consolidated_non_operating_expense: consolidated_statement[:non_operating_expense],
          consolidated_ordinary_income: consolidated_statement[:ordinary_income],
          consolidated_extraordinary_income: consolidated_statement[:extraordinary_income],
          consolidated_extraordinary_loss: consolidated_statement[:extraordinary_loss],
          consolidated_income_before_income_tax: consolidated_statement[:income_before_income_tax],
          consolidated_income_tax: consolidated_statement[:income_tax],
          consolidated_profit_loss: consolidated_statement[:profit_loss],
          consolidated_profit_loss_attributable_to_owners_of_parent: consolidated_statement[:profit_loss_attributable_to_owners_of_parent],
          consolidated_start_cash_flow_balance: consolidated_statement[:start_cash_flow_balance],
          consolidated_operating_activity_cash_flow: consolidated_statement[:operating_activity_cash_flow],
          consolidated_investment_activity_cash_flow: consolidated_statement[:investment_activity_cash_flow],
          consolidated_financing_activity_cash_flow: consolidated_statement[:financing_activity_cash_flow],
          consolidated_end_cash_flow_balance: consolidated_statement[:end_cash_flow_balance],
          # 単体財務諸表
          non_consolidated_current_asset: non_consolidated_statement[:current_asset],
          non_consolidated_property_plant_and_equipment: non_consolidated_statement[:property_plant_and_equipment],
          non_consolidated_intangible_asset: non_consolidated_statement[:intangible_asset],
          non_consolidated_investment_and_other_asset: non_consolidated_statement[:investment_and_other_asset],
          non_consolidated_non_current_asset: non_consolidated_statement[:non_current_asset],
          non_consolidated_asset: non_consolidated_statement[:asset],
          non_consolidated_current_liability: non_consolidated_statement[:current_liability],
          non_consolidated_non_current_liability: non_consolidated_statement[:non_current_liability],
          non_consolidated_liability: non_consolidated_statement[:liability],
          non_consolidated_net_asset: non_consolidated_statement[:net_asset],
          non_consolidated_net_sales: non_consolidated_statement[:net_sales],
          non_consolidated_cost_of_sales: non_consolidated_statement[:cost_of_sales],
          non_consolidated_gross_profit: non_consolidated_statement[:gross_profit],
          non_consolidated_selling_general_and_administrative_expense: non_consolidated_statement[:selling_general_and_administrative_expense],
          non_consolidated_operating_income: non_consolidated_statement[:operating_income],
          non_consolidated_non_operating_income: non_consolidated_statement[:non_operating_income],
          non_consolidated_non_operating_expense: non_consolidated_statement[:non_operating_expense],
          non_consolidated_ordinary_income: non_consolidated_statement[:ordinary_income],
          non_consolidated_extraordinary_income: non_consolidated_statement[:extraordinary_income],
          non_consolidated_extraordinary_loss: non_consolidated_statement[:extraordinary_loss],
          non_consolidated_income_before_income_tax: non_consolidated_statement[:income_before_income_tax],
          non_consolidated_income_tax: non_consolidated_statement[:income_tax],
          non_consolidated_profit_loss: non_consolidated_statement[:profit_loss],
          non_consolidated_profit_loss_attributable_to_owners_of_parent: non_consolidated_statement[:profit_loss_attributable_to_owners_of_parent],
          non_consolidated_start_cash_flow_balance: non_consolidated_statement[:start_cash_flow_balance],
          non_consolidated_operating_activity_cash_flow: non_consolidated_statement[:operating_activity_cash_flow],
          non_consolidated_investment_activity_cash_flow: non_consolidated_statement[:investment_activity_cash_flow],
          non_consolidated_financing_activity_cash_flow: non_consolidated_statement[:financing_activity_cash_flow],
          non_consolidated_end_cash_flow_balance: non_consolidated_statement[:end_cash_flow_balance]
        }, unique_by: [:company_id, :fiscal_year_start_date, :fiscal_year_end_date])
      end
  end
end
