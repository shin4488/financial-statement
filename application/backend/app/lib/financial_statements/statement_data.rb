module FinancialStatements
  # 抽出結果と保存済みの財務諸表を、DBに依存せずに同じ形で表す値。等しいかは属性の値だけで決まる。
  # 連結区分はシンボル（:consolidated・:non_consolidated）、会計基準と形式は文字列で持つ
  StatementData = Data.define(:consolidation_type, :accounting_standard, :presentation_format, :amounts, :disclosed_roe, :fiscal_year_end_date) do
    # 連結区分は、抽出結果（シンボル）とARモデル（文字列）のどちらから作っても同じ値にする。
    # 金額と端数は、渡されたものを複製して凍結する。作った後に変わらず、渡した側の金額は凍結しないように
    def initialize(consolidation_type:, amounts:, **)
      super(consolidation_type: consolidation_type.to_sym, amounts: amounts.dup.freeze, **)
    end

    def consolidated? = consolidation_type == :consolidated
  end
end
