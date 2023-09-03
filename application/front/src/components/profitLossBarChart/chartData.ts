interface Credit {
  originalCostAmount: number;
  sellingGeneralExpenseAmount: number;
  operatingIncomeAmount: number;
  originalCostRatio: number;
  sellingGeneralExpenseRatio: number;
  operatingIncomeRatio: number;
}

interface Debt {
  netSalesAmount: number;
  operatingLossAmount: number;
  netSalesRatio: number;
  operatingLossRatio: number;
}

export type ProfitLossChart = [Credit, Debt];

export type ProfitLossAmountKeyLabel = {
  [K in (keyof Credit | keyof Debt) &
    (
      | 'originalCostAmount'
      | 'sellingGeneralExpenseAmount'
      | 'operatingIncomeAmount'
      | 'netSalesAmount'
      | 'operatingLossAmount'
    )]: string;
};
