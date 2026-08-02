module Disclosure
  # 有報一覧の検索（証券コード・CF符号フィルタ）
  class SearchQuery
    CF_CODES = {
      operating: "cf.operating", investing: "cf.investing", financing: "cf.financing",
    }.freeze

    # cf_signs: { operating: :positive|:negative|nil, ... }
    def call(limit:, offset:, stock_codes: nil, cf_signs: {})
      # preload（eager_loadでなく）にする理由: EXISTSを生SQLで書くためActiveRecordが
      # 参照テーブルを検知できず、eager_loadのJOIN+limitの組み合わせで挙動が複雑になる。
      # 別クエリのpreloadならlimitが主テーブルにだけ効くことが自明になる
      scope = Disclosure::Report.joins(:primary_financial_statement)
                                .preload(:company, primary_financial_statement: :items)
                                .order(Disclosure::Report.arel_table[:filing_date].desc.nulls_last,
                                       fiscal_year_end_date: :desc, updated_at: :desc)
                                .limit(limit).offset(offset)
      if stock_codes.present?
        # 証券コードはEDINET上5桁（4桁コード+チェック用の末尾"0"）。UIは4桁入力のため0パディングして照合する
        scope = scope.joins(:company).where(companies: { stock_code: stock_codes.map { |c| "#{c}0" } })
      end
      cf_signs.compact.each do |key, sign|
        # opの文字列埋め込みはSQLインジェクション安全: :positive/:negative の2値からしか
        # 生成されない（GraphQL enumで制約済み）。item_codeの方はユーザ入力経路がないが
        # 一貫性のためプレースホルダでバインドする
        op = sign == :positive ? ">" : "<"
        scope = scope.where(<<~SQL, CF_CODES.fetch(key))
          EXISTS (SELECT 1 FROM financial_statement_items i
                  WHERE i.financial_statement_id = financial_statements.id
                    AND i.item_code = ? AND i.amount #{op} 0)
        SQL
      end
      scope
    end
  end
end
