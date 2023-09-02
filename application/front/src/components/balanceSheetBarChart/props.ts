interface BalanceSheetDetail {
  currentAsset: number;
  // 有形固定資産
  propertyPlantAndEquipment: number;
  // 無形固定資産
  intangibleAsset: number;
  // 投資その他の資産
  investmentAndOtherAsset: number;
  currentLiability: number;
  noncurrentLiability: number;
  netAsset: number;
}

export interface BalanceSheetBarChartProps {
  amount: BalanceSheetDetail;
  ratio: BalanceSheetDetail;
}
