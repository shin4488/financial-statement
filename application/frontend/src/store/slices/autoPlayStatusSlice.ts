import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { autoPlayStatusLocalStorageKey } from '@/constants/values';
import { readLocalStorage } from '@/utils/localStorage';

export const autoPlayStatusSlice = createSlice({
  name: 'autoPlayStatus',
  initialState: {
    // 保存済みのユーザ設定を復元する。明示的にOFFにした場合のみfalse（未保存・読めない場合はONで開始）
    isAutoPlay: readLocalStorage(autoPlayStatusLocalStorageKey) !== 'false',
  },
  reducers: {
    changeAutoPlayStatus: (state, action: PayloadAction<boolean>) => {
      state.isAutoPlay = action.payload;
    },
  },
});

export const { changeAutoPlayStatus } = autoPlayStatusSlice.actions;
export default autoPlayStatusSlice.reducer;
