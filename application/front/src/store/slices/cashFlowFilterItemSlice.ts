import { createSlice } from '@reduxjs/toolkit';
import {
  ChangeCashFlowFilterAction,
  ChangeStockCodeFilterAction,
} from './action';

export const cashFlowFilterSlice = createSlice({
  name: 'cashFlowFilter',
  initialState: {
    filterItem: 'none',
    stockCodes: [].map(String),
  },
  reducers: {
    changeCashFlowFilter: (state, action: ChangeCashFlowFilterAction) => {
      state.filterItem = action.payload;
    },
    changeStockCodeFilter: (state, action: ChangeStockCodeFilterAction) => {
      state.stockCodes = action.payload;
    },
  },
});

export const { changeCashFlowFilter, changeStockCodeFilter } =
  cashFlowFilterSlice.actions;
export default cashFlowFilterSlice.reducer;
