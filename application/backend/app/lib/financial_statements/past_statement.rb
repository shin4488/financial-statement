module FinancialStatements
  # FCF推移の1年に使う、過去の主の財務諸表。金額はCFの式に使う科目だけを持つ
  PastStatement = Data.define(:company_id, :fiscal_year_start_date, :fiscal_year_end_date, :consolidation_type, :amounts) do
    # StatementData と同じく、連結区分はシンボルにし、金額と端数は複製して凍結する
    def initialize(consolidation_type:, amounts:, **)
      super(consolidation_type: consolidation_type.to_sym, amounts: amounts.dup.freeze, **)
    end
  end
end
