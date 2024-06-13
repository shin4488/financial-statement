import { createSlice } from '@reduxjs/toolkit';
import {
  ChangeCashFlowFilterAction,
  ChangeStockCodeFilterAction,
} from './action';
import { CashFlowTypeValue } from '@/constants/values';

export const financialStatementFilterSlice = createSlice({
  name: 'financialStatementFilter',
  initialState: {
    cashFlowType: 'none' as CashFlowTypeValue,
    stockCodes: [].map(String),
  },
  reducers: {
    changeCashFlowFilter: (state, action: ChangeCashFlowFilterAction) => {
      state.cashFlowType = action.payload;
    },
    changeStockCodeFilter: (state, action: ChangeStockCodeFilterAction) => {
      state.stockCodes = action.payload;
    },
  },
});

export const { changeCashFlowFilter, changeStockCodeFilter } =
  financialStatementFilterSlice.actions;
export default financialStatementFilterSlice.reducer;
