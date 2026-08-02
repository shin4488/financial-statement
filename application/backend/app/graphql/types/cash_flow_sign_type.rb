module Types
  # FinancialStatement::NumberSignType を再利用しない理由: あちらは
  # companyFinancialStatements 系の型ツリーに属し、廃止時に一括削除される。
  # financialReports 系の引数型を巻き込まれないよう独立して持つ
  class CashFlowSignType < Types::BaseEnum
    graphql_name "CashFlowSign"
    value "POSITIVE", value: :positive
    value "NEGATIVE", value: :negative
  end
end
