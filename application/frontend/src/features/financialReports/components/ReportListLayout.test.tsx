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
