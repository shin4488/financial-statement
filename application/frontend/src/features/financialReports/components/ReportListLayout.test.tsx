import React from 'react';
import { Provider } from 'react-redux';
import { MemoryRouter } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { ReportListLayout } from './ReportListLayout';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import { autoPlayStatusLocalStorageKey } from '@/constants/values';

vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
}));

const localStorageProperty = Object.getOwnPropertyDescriptor(
  window,
  'localStorage',
) as PropertyDescriptor;

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  Object.defineProperty(window, 'localStorage', localStorageProperty);
  localStorage.clear();
});

function renderLayout() {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay: true } },
  });
  render(
    <Provider store={store}>
      <MemoryRouter>
        <ReportListLayout>{null}</ReportListLayout>
      </MemoryRouter>
    </Provider>,
  );
  const checkbox = screen.getByRole('checkbox', {
    name: '自動切替',
  }) as HTMLInputElement;
  return { store, checkbox };
}

describe('支援技術に伝える名前と見出し', () => {
  it('情報ボタンを「カードの見方」という名前で伝える', () => {
    renderLayout();
    screen.getByRole('button', { name: 'カードの見方' });
  });

  it('情報のツールチップを開いても、情報ボタンの名前は「カードの見方」のままで、ツールチップの中身を説明として伝える', async () => {
    renderLayout();
    fireEvent.mouseOver(screen.getByRole('button', { name: 'カードの見方' }));
    await screen.findByRole('tooltip');
    screen.getByRole('button', {
      name: 'カードの見方',
      description:
        /^カードはBS → PL → CF → フリーCF → ROE・ROAの順に切り替わります/,
    });
  });

  it('キャッシュフローの選択欄を「キャッシュフロー」という名前で伝える', () => {
    renderLayout();
    const select = screen.getByRole('button', { name: 'キャッシュフロー' });
    expect(select.getAttribute('aria-haspopup')).toBe('listbox');
  });

  it('一覧の領域（main）の先頭に、見出し（h1）「財務諸表の一覧」を置く', () => {
    renderLayout();
    const heading = screen.getByRole('heading', {
      level: 1,
      name: '財務諸表の一覧',
    });
    expect(screen.getByRole('main').firstElementChild).toBe(heading);
  });
});

describe('自動切替のチェック', () => {
  it('切り替えた設定を保存する', () => {
    const { store, checkbox } = renderLayout();
    fireEvent.click(checkbox);
    expect(store.getState().autoPlayStatus.isAutoPlay).toBe(false);
    expect(localStorage.getItem(autoPlayStatusLocalStorageKey)).toBe('false');
    fireEvent.click(checkbox);
    expect(store.getState().autoPlayStatus.isAutoPlay).toBe(true);
    expect(localStorage.getItem(autoPlayStatusLocalStorageKey)).toBe('true');
  });

  it.each([
    [
      'localStorageに触れると例外になる（サイトデータの保存をブロックした）',
      () =>
        Object.defineProperty(window, 'localStorage', {
          configurable: true,
          get() {
            throw new DOMException(
              "Failed to read the 'localStorage' property from 'Window': Access is denied for this document.",
              'SecurityError',
            );
          },
        }),
    ],
    [
      'setItemが例外になる（容量が足りない）',
      () =>
        vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
          throw new DOMException(
            'The quota has been exceeded.',
            'QuotaExceededError',
          );
        }),
    ],
  ])(
    '%sブラウザでも、例外を出さずに切り替えがその場で効く',
    (_, makeStorageFail) => {
      const { store, checkbox } = renderLayout();
      makeStorageFail();
      // イベントハンドラで捕捉されなかった例外は、windowのerrorイベントとして届く
      const uncaught: unknown[] = [];
      const collect = (event: ErrorEvent) => uncaught.push(event.error);
      window.addEventListener('error', collect);
      try {
        fireEvent.click(checkbox);
        expect(checkbox.checked).toBe(false);
        expect(store.getState().autoPlayStatus.isAutoPlay).toBe(false);
        fireEvent.click(checkbox);
        expect(checkbox.checked).toBe(true);
        expect(store.getState().autoPlayStatus.isAutoPlay).toBe(true);
      } finally {
        window.removeEventListener('error', collect);
      }
      expect(uncaught).toEqual([]);
    },
  );
});
