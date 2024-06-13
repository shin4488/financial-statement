class SecurityReport < ApplicationRecord
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  belongs_to :company

  class << self
    def fetch_company_security_reports(limit:, offset: 0, stock_codes: nil)
      # 提出日のみのorderだと実行ごとに並び替え順番が異なり得るため、日時を値にもつupdated_atもorderに加えて、何回実行しても同じ並び順となるようにする
      SecurityReport.eager_load(:company)
        .where(create_conditional_stock_code_clause(stock_codes))
        .where(accounting_standard: "japan_gaap")
        .order(SecurityReport.arel_table[:filing_date].desc.nulls_last, fiscal_year_end_date: :desc, updated_at: :desc)
        .limit(limit)
        .offset(offset)
    end

    def fetch_company_security_reports_with_cash_flow_condition(limit:, offset: 0, stock_codes: nil, cash_flow_condition:)
      # 提出日のみのorderだと実行ごとに並び替え順番が異なり得るため、日時を値にもつupdated_atもorderに加えて、何回実行しても同じ並び順となるようにする
      main_condition = SecurityReport.eager_load(:company)
        .where(accounting_standard: "japan_gaap")
        .where(create_conditional_stock_code_clause(stock_codes))
      # 連結財務諸表があるときは連結キャッシュフローを見て、ない時は単体キャッシュフローを見る。どちらかでデータがあれば取得する
      consolidated_clause = create_consolidated_cash_flow_clause(cash_flow_condition)
      consolidated_condition = SecurityReport.where(has_consolidated_financial_statement: true).where(consolidated_clause)
      non_consolidated_clause = create_non_consolidated_cash_flow_clause(cash_flow_condition)
      non_consolidated_condition = SecurityReport.where(has_consolidated_financial_statement: false).where(non_consolidated_clause)

      main_condition
        .merge(consolidated_condition.or(non_consolidated_condition))
        .order(SecurityReport.arel_table[:filing_date].desc.nulls_last, fiscal_year_end_date: :desc, updated_at: :desc)
        .limit(limit)
        .offset(offset)
    end

    private

      # 証券コードが存在する時のみ有効となるWHERE句を作成する
      def create_conditional_stock_code_clause(stock_codes)
        { company: { stock_code: stock_codes.presence }.compact.presence }.compact.presence
      end

      # 「a < 0 AND b > 0」のようなWHERE句の条件を作成する
      def create_consolidated_cash_flow_clause(condition)
        {
          operating_activities_cash_flow_sign: "consolidated_operating_activity_cash_flow",
          investing_activities_cash_flow_sign: "consolidated_investment_activity_cash_flow",
          financing_activities_cash_flow_sign: "consolidated_financing_activity_cash_flow",
        }.map { |parameter_key, sql_column|
          sign = create_inequality_sign(condition[parameter_key])
          "#{sql_column} #{sign} 0 " unless sign.nil?
        }.compact.join(" AND ")
      end

      def create_non_consolidated_cash_flow_clause(condition)
        {
          operating_activities_cash_flow_sign: "non_consolidated_operating_activity_cash_flow",
          investing_activities_cash_flow_sign: "non_consolidated_investment_activity_cash_flow",
          financing_activities_cash_flow_sign: "non_consolidated_financing_activity_cash_flow",
        }.map { |parameter_key, sql_column|
          sign = create_inequality_sign(condition[parameter_key])
          "#{sql_column} #{sign} 0 " unless sign.nil?
        }.compact.join(" AND ")
      end

      def create_inequality_sign(sign)
        if sign == :positive
          ">"
        elsif sign == :negative
          "<"
        end
      end
  end
end
