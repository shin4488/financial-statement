import { CashFlowTypeValue } from '@/constants/values';

export interface ChangeAutoPlayStatusAction {
  type: string;
  payload: boolean;
}

export interface ChangeCashFlowFilterAction {
  type: string;
  payload: CashFlowTypeValue;
}

export interface ChangeStockCodeFilterAction {
  type: string;
  payload: string[];
}
