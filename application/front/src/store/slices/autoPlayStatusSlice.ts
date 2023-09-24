import { createSlice } from '@reduxjs/toolkit';
import { ChangeAutoPlayStatusAction } from './action';

export const autoPlayStatusSlice = createSlice({
  name: 'isAutoPlay',
  initialState: {
    isAutoPlay: true,
  },
  reducers: {
    changeAutoPlayStatus: (state, action: ChangeAutoPlayStatusAction) => {
      state.isAutoPlay = action.payload;
    },
  },
});

export const { changeAutoPlayStatus } = autoPlayStatusSlice.actions;
export default autoPlayStatusSlice.reducer;
