interface Debit {
  originalCostAmount: number;
  sellingGeneralExpenseAmount: number;
  operatingIncomeAmount: number;
  originalCostRatio: number;
  sellingGeneralExpenseRatio: number;
  operatingIncomeRatio: number;
}

interface Credit {
  netSalesAmount: number;
  operatingLossAmount: number;
  netSalesRatio: number;
  operatingLossRatio: number;
}

export type ProfitLossChart = [Debit, Credit];

export type ProfitLossAmountKeyLabel = {
  [K in (keyof Debit | keyof Credit) &
    (
      | 'originalCostAmount'
      | 'sellingGeneralExpenseAmount'
      | 'operatingIncomeAmount'
      | 'netSalesAmount'
      | 'operatingLossAmount'
    )]: string;
};
