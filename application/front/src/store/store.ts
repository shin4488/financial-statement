import { configureStore } from '@reduxjs/toolkit';
import autoPlayStatusReducer from './slices/autoPlayStatusSlice';
import cashFlowFilterReducer from './slices/cashFlowFilterItemSlice';

export const store = configureStore({
  reducer: {
    autoPlayStatus: autoPlayStatusReducer,
    cashFlowFilter: cashFlowFilterReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
// stateの型定義
export type RootState = ReturnType<typeof store.getState>;
