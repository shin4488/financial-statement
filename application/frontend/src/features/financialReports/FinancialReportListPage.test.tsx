import React from 'react';
import { Provider } from 'react-redux';
import { MemoryRouter, useLocation } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import FinancialReportListPage from './FinancialReportListPage';
import { financialReportsClient } from './apolloClient';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';

vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
}));

// APIへ送った証券コード（リクエストごと）
let requestedStockCodes: (string[] | null)[];

beforeEach(() => {
  requestedStockCodes = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (_url: string, init: RequestInit) => {
      const { variables } = JSON.parse(String(init.body));
      requestedStockCodes.push(variables.stockCodes);
      return new Response(JSON.stringify({ data: { financialReports: [] } }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }),
  );
});

afterEach(async () => {
  cleanup();
  vi.unstubAllGlobals();
  await financialReportsClient.clearStore();
});

function CurrentStockCodes() {
  const { search } = useLocation();
  return (
    <output data-testid="url-stock-codes">
      {new URLSearchParams(search).get('stock-codes')}
    </output>
  );
}

function renderPage(url: string) {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay: false } },
  });
  render(
    <Provider store={store}>
      <MemoryRouter initialEntries={[url]}>
        <FinancialReportListPage />
        <CurrentStockCodes />
      </MemoryRouter>
    </Provider>,
  );
}

function enterStockCode(code: string) {
  const input = screen.getByLabelText('証券コードで検索（複数可）');
  fireEvent.change(input, { target: { value: code } });
  fireEvent.keyDown(input, { key: 'Enter' });
}

// 応答（0件）を画面に反映し終えるまで待つ
const searchFinished = () =>
  screen.findByText('条件に一致する企業がありません。');

const chipLabels = () =>
  Array.from(document.querySelectorAll('header .MuiChip-label')).map(
    (chip) => chip.textContent,
  );

const urlStockCodes = () => screen.getByTestId('url-stock-codes').textContent;

describe('証券コードの検索', () => {
  it('入力済みのコードを大文字・小文字だけ変えて入れても、検索条件とAPIへの引数は増えない', async () => {
    renderPage('/?stock-codes=7203,604A');
    await searchFinished();

    enterStockCode('604a');
    expect(chipLabels()).toEqual(['7203', '604A']);
    expect(urlStockCodes()).toBe('7203,604A');

    // 別のコードを入れて次の検索を待つ。その間に重複したコードで検索していれば、下の比較で分かる
    enterStockCode('6758');
    await searchFinished();
    expect(requestedStockCodes).toEqual([
      ['7203', '604A'],
      ['7203', '604A', '6758'],
    ]);
    expect(chipLabels()).toEqual(['7203', '604A', '6758']);
    expect(urlStockCodes()).toBe('7203,604A,6758');
  });

  it('URLに大文字・小文字だけ違うコードがあれば、1つにまとめて検索する', async () => {
    renderPage('/?stock-codes=604A,604a');
    await searchFinished();

    expect(requestedStockCodes).toEqual([['604A']]);
    expect(chipLabels()).toEqual(['604A']);
  });
});
