import { configureStore } from '@reduxjs/toolkit';
import autoPlayStatusReducer from './slices/autoPlayStatusSlice';
import financialStatementFilterReducer from './slices/financialStatementFilterSlice';

export const store = configureStore({
  reducer: {
    autoPlayStatus: autoPlayStatusReducer,
    financialStatementFilter: financialStatementFilterReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
// stateの型定義
export type RootState = ReturnType<typeof store.getState>;
