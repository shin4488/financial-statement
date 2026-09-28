module Types
  module Chart
    class FreeCashFlowPointType < Types::BaseObject
      field :year, Integer, null: false, description: "決算期末の暦年"
      field :fiscal_year_start_date, String, null: true
      field :fiscal_year_end_date, String, null: true
      field :operating_cf, Types::MoneyType, null: true
      field :investing_cf, Types::MoneyType, null: true
      field :amount, Types::MoneyType, null: true, description: "営業CF＋投資CF。欠損時はnull"
    end
  end
end
