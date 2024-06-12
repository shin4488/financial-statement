export interface ChangeAutoPlayStatusAction {
  type: string;
  payload: boolean;
}

export interface ChangeCashFlowFilterAction {
  type: string;
  payload: string;
}

export interface ChangeStockCodeFilterAction {
  type: string;
  payload: string[];
}
