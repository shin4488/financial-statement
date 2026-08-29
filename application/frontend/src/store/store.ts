import { configureStore } from '@reduxjs/toolkit';
import autoPlayStatusReducer from './slices/autoPlayStatusSlice';

export const store = configureStore({
  reducer: {
    autoPlayStatus: autoPlayStatusReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
export type RootState = ReturnType<typeof store.getState>;
