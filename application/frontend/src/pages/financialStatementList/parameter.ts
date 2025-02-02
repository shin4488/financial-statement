import { CashFlowTypeValue } from '@/constants/values';

export interface FinancialStatementConditionParameter {
  cashFlowType: CashFlowTypeValue;
  stockCodes: string[];
}
