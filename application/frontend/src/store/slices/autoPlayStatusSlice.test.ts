import { autoPlayStatusLocalStorageKey } from '@/constants/values';

const localStorageProperty = Object.getOwnPropertyDescriptor(
  window,
  'localStorage',
) as PropertyDescriptor;

afterEach(() => {
  Object.defineProperty(window, 'localStorage', localStorageProperty);
  localStorage.clear();
});

// sliceは読み込んだときに保存済みの設定を読むため、テストごとに読み込み直す
async function initialState() {
  vi.resetModules();
  const { default: reducer } = await import('./autoPlayStatusSlice');
  return reducer(undefined, { type: 'init' });
}

describe('自動切替の初期値', () => {
  it('保存がなければON', async () => {
    expect(await initialState()).toEqual({ isAutoPlay: true });
  });

  it('OFFを保存していればOFF', async () => {
    localStorage.setItem(autoPlayStatusLocalStorageKey, 'false');
    expect(await initialState()).toEqual({ isAutoPlay: false });
  });

  it('サイトデータの保存をブロックしたブラウザ（localStorageに触れると例外になる）でも読み込めて、ONで始まる', async () => {
    Object.defineProperty(window, 'localStorage', {
      configurable: true,
      get() {
        throw new DOMException(
          "Failed to read the 'localStorage' property from 'Window': Access is denied for this document.",
          'SecurityError',
        );
      },
    });
    expect(await initialState()).toEqual({ isAutoPlay: true });
  });
});
