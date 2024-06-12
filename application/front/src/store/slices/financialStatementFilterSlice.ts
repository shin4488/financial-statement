import { createSlice } from '@reduxjs/toolkit';
import {
  ChangeCashFlowFilterAction,
  ChangeStockCodeFilterAction,
} from './action';

export const financialStatementFilterSlice = createSlice({
  name: 'financialStatementFilter',
  initialState: {
    cashFlowType: 'none',
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
