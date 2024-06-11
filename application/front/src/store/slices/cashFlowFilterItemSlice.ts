import { createSlice } from '@reduxjs/toolkit';
import { ChangeCashFlowFilterAction } from './action';

export const cashFlowFilterSlice = createSlice({
  name: 'cashFlowFilter',
  initialState: {
    filterItem: 'none',
  },
  reducers: {
    changeCashFlowFilter: (state, action: ChangeCashFlowFilterAction) => {
      state.filterItem = action.payload;
    },
  },
});

export const { changeCashFlowFilter } = cashFlowFilterSlice.actions;
export default cashFlowFilterSlice.reducer;
