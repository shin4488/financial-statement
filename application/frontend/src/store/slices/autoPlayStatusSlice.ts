import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { autoPlayStatusLocalStorageKey } from '@/constants/values';

export const autoPlayStatusSlice = createSlice({
  name: 'autoPlayStatus',
  initialState: {
    // 保存済みのユーザ設定を復元する。明示的にOFFにした場合のみfalse（未保存はONで開始）
    isAutoPlay: localStorage.getItem(autoPlayStatusLocalStorageKey) !== 'false',
  },
  reducers: {
    changeAutoPlayStatus: (state, action: PayloadAction<boolean>) => {
      state.isAutoPlay = action.payload;
    },
  },
});

export const { changeAutoPlayStatus } = autoPlayStatusSlice.actions;
export default autoPlayStatusSlice.reducer;
