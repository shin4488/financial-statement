module Disclosure
  # 有報一覧の検索（証券コード・CF符号フィルタ）
  class SearchQuery
    CF_CODES = {
      operating: "cf.operating", investing: "cf.investing", financing: "cf.financing"
    }.freeze

    # cf_signs: { operating: :positive|:negative|nil, ... }
    def call(limit:, offset:, stock_codes: nil, cf_signs: {})
      # preload（eager_loadでなく）にする理由: CF符号を生SQLのサブクエリで書くためActiveRecordが
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
      apply_cf_signs(scope, cf_signs.compact)
    end

    private
      # 符号ごとに相関EXISTSを並べない理由: 該当する財務諸表の数だけ科目テーブルへの
      # 索引探索が繰り返され、多数が一致する符号パターンではキャッシュが冷えていると
      # 秒単位まで遅くなるため。科目テーブルを1回のスキャンで済ませ、
      # 「指定した符号を全て満たす財務諸表id」をGROUP BY/HAVINGで集める。
      # COUNT(*)と符号条件数の一致で全条件充足とみなせるのは、
      # (financial_statement_id, item_code)がユニークで同一科目の重複行がないため
      def apply_cf_signs(scope, cf_signs)
        return scope if cf_signs.empty?

        # opの文字列埋め込みはSQLインジェクション安全: :positive/:negative の2値からしか
        # 生成されない（GraphQL enumで制約済み）。item_codeの方はユーザ入力経路がないが
        # 一貫性のためプレースホルダでバインドする
        conditions = cf_signs.map do |_key, sign|
          op = sign == :positive ? ">" : "<"
          "(item_code = ? AND amount #{op} 0)"
        end
        scope.where(<<~SQL, *cf_signs.keys.map { |key| CF_CODES.fetch(key) })
          financial_statements.id IN (
            SELECT financial_statement_id FROM financial_statement_items
            WHERE #{conditions.join(" OR ")}
            GROUP BY financial_statement_id
            HAVING COUNT(*) = #{conditions.size}
          )
        SQL
      end
  end
end
