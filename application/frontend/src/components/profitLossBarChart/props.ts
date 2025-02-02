export interface ProfitLossDetail {
  netSales: number;
  // 売上原価
  originalCost: number;
  // 販売一般管理費
  sellingGeneralExpense: number;
  operatingIncome: number;
}

export interface ProfitLossBarChartProps {
  amount: ProfitLossDetail;
  ratio: ProfitLossDetail;
}
