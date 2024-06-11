import { BalanceSheetBarChartProps } from '@/components/balanceSheetBarChart/props';
import { CashFlowBarChartProps } from '@/components/cashFlowBarChart/props';
import { ProfitLossBarChartProps } from '@/components/profitLossBarChart/props';
import FinancialStatementListStateService from './service';

export interface FinancialStatement {
  fiscalYearStartDate: string;
  fiscalYearEndDate: string;
  companyName: string;
  stockCode: string;
  hasConsolidatedFinancialStatement: boolean;
  consolidatedInductoryCode: string;
  nonConsolidatedInductoryCode: string;
  balanceSheet: BalanceSheetBarChartProps;
  profitLoss: ProfitLossBarChartProps;
  cashFlow: CashFlowBarChartProps;
}

export interface FinancialStatementListState {
  service: FinancialStatementListStateService;
  shouldLoadMore: boolean;
  financialStatements: FinancialStatement[];
  infiniteScrollKey: number;
}
