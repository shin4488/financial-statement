module Resolvers
  # QueryTypeに直接実装せずresolverクラスに切り出す理由:
  # QueryTypeの肥大化を避け、financialReports系の入出力整形をこの1ファイルに閉じ込めるため
  class FinancialReports < GraphQL::Schema::Resolver
    type [ Types::FinancialReportType ], null: false
    description "有報の財務3表チャート一覧（提出日降順）"

    # 既定の複雑度は引数を見ないため limit:1 と limit:100 が同コスト扱いになり、
    # エイリアスを並べるだけで上限内に高負荷リクエストを作れてしまう。
    # 実測したコストは「エイリアス数 x (固定コスト + 件数比例分)」の形のため、
    # child_complexityで固定コスト分を、limitの項で件数比例分を負担させる
    complexity ->(_ctx, args, child_complexity) { child_complexity + args[:limit] / 2 }

    argument :limit, Integer, required: true,
             validates: { numericality: { greater_than: 0, less_than_or_equal_to: 100 } }
    argument :offset, Integer, required: true,
             validates: { numericality: { greater_than_or_equal_to: 0 } }
    # 件数上限はlimitと同水準: 無制限だと巨大なIN句を未認証で生成できてしまうため
    argument :stock_codes, [ String ], required: false,
             validates: { length: { maximum: 100 } }
    argument :operating_cf_sign, Types::CashFlowSignType, required: false
    argument :investing_cf_sign, Types::CashFlowSignType, required: false
    argument :financing_cf_sign, Types::CashFlowSignType, required: false

    def resolve(limit:, offset:, stock_codes: nil,
                operating_cf_sign: nil, investing_cf_sign: nil, financing_cf_sign: nil)
      reports = Disclosure::SearchQuery.new.call(
        limit: limit, offset: offset, stock_codes: stock_codes,
        cf_signs: { operating: operating_cf_sign, investing: investing_cf_sign, financing: financing_cf_sign })
      reports.map { |report| present(report) }
    end

    private
      # 戻り値はシンボルキーのHash + チャート部分はStruct。
      # graphql-rubyはHashをシンボルキーで、Structをメソッド呼び出しで解決するため
      # この混在で追加の変換層なしにフィールドが引ける。
      # 専用のPresenterクラスにしない理由: 整形がこのメソッド1つに収まる薄さであり、
      # 科目・形式の知識は既にBuilder側に隔離されているため
      def present(report)
        fs = report.primary_financial_statement
        charts = Charts::BuilderRegistry.build_all(fs)
        {
          id: report.id,
          stock_code: report.company.stock_code&.delete_suffix("0"),
          # 有報に保存した提出時点の名前を優先する: 社名変更があった企業でも、
          # 各年度の有報は当時の企業名で表示するため（companiesは最新名のマスタ）
          company_name: report.company_name_ja || report.company.name_ja,
          fiscal_year_start_date: report.fiscal_year_start_date.to_s,
          fiscal_year_end_date: report.fiscal_year_end_date.to_s,
          filing_date: report.filing_date&.to_s,
          accounting_standard: fs.accounting_standard,
          consolidation_type: fs.consolidation_type,
          presentation_format: fs.presentation_format,
          **charts # balance_sheet: / profit_loss: / cash_flow: が展開される
        }
      end
  end
end
