// Webと拡張で共通の描画契約。生成型や状態管理には依存しない。
export interface FinancialMetric {
  value?: number | null;
  status: 'AVAILABLE' | 'MISSING_DATA' | 'NOT_CALCULABLE';
}

export interface FinancialIndicatorsData {
  roe: FinancialMetric & { source?: 'CALCULATED' | 'DISCLOSED' | null };
  roa: FinancialMetric;
  netProfitMargin: FinancialMetric;
  assetTurnover: FinancialMetric;
  financialLeverage: FinancialMetric;
}
