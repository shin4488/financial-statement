import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { MemoryRouter, NavigateFunction, useNavigate } from 'react-router-dom';
import { act, cleanup, render, screen, waitFor } from '@testing-library/react';
import FinancialReportListPage from './FinancialReportListPage';
import { financialReportsClient } from './apolloClient';
import type { FinancialReport } from './api/types';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';

// カードの中身はこのテストの対象外。表示された企業を数えられるよう、企業名だけを出す
vi.mock('./components/ReportCard', () => ({
  ReportCard: ({ report }: { report: FinancialReport }) => (
    <article>{report.companyName}</article>
  ),
}));

const pageSize = 30;
const failureMessage =
  '財務データを取得できませんでした。時間をおいて再度お試しください。';

const missing = { value: null, status: 'MISSING_DATA' };
const unavailable = { renderable: false, note: null };
const reports = (offset: number, count: number) =>
  Array.from({ length: count }, (_, index) => ({
    __typename: 'FinancialReport',
    id: String(offset + index),
    stockCode: null,
    companyName: `企業${offset + index}`,
    fiscalYearStartDate: '2025-04-01',
    fiscalYearEndDate: '2026-03-31',
    accountingStandard: 'japan_gaap',
    consolidationType: 'consolidated',
    financialIndicators: {
      roe: { ...missing, source: null },
      roa: missing,
      netProfitMargin: missing,
      assetTurnover: missing,
      financialLeverage: missing,
    },
    balanceSheet: { ...unavailable, bars: [] },
    profitLoss: { ...unavailable, bars: [] },
    cashFlow: { ...unavailable, steps: [] },
    freeCashFlowTrend: { ...unavailable, points: [] },
  }));

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
const page = (offset: number, count = pageSize) =>
  json({ data: { financialReports: reports(offset, count) } });

// APIの代わりに、要求されたoffsetを記録して、テストごとに決めた応答を返す。
// 本物の通信と同じく応答は別のタスクで返す（送り直しが止まらない不具合が戻っても、待ち時間の上限でテストが終わるようにする）。
type Variables = { offset: number; stockCodes: string[] | null };
let reply: (
  offset: number,
  variables: Variables,
) => Response | Promise<Response>;
let requestedOffsets: number[] = [];

// jsdomはレイアウトを計算しないため、カード1枚の高さと縦のスクロール位置をブラウザの代わりに与える。
// 一覧はページの先頭から始まり、要素の高さは中のカードの枚数で決まるものとする
const cardHeight = 400;
let scrollTop = 0;

beforeEach(() => {
  requestedOffsets = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const { variables } = JSON.parse(String(init?.body));
      requestedOffsets.push(variables.offset);
      await new Promise((resolve) => setTimeout(resolve, 0));
      return reply(variables.offset, variables);
    }),
  );
  scrollTop = 0;
  Object.defineProperty(window, 'pageYOffset', {
    configurable: true,
    get: () => scrollTop,
  });
  Object.defineProperty(HTMLElement.prototype, 'offsetParent', {
    configurable: true,
    get(this: HTMLElement) {
      return this === document.body ? null : document.body;
    },
  });
  Object.defineProperty(HTMLElement.prototype, 'offsetHeight', {
    configurable: true,
    get(this: HTMLElement) {
      return this.querySelectorAll('article').length * cardHeight;
    },
  });
  Object.defineProperty(HTMLElement.prototype, 'getBoundingClientRect', {
    configurable: true,
    value(this: HTMLElement) {
      const top = -scrollTop;
      const height = this.offsetHeight;
      return { top, bottom: top + height, height } as DOMRect;
    },
  });
});

afterEach(async () => {
  cleanup();
  vi.unstubAllGlobals();
  await financialReportsClient.clearStore();
});

// 検索条件の切り替え（URLの変更）をテストから行う
let navigate: NavigateFunction = () => undefined;
function CaptureNavigate() {
  navigate = useNavigate();
  return null;
}

function renderPage() {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
  });
  const tree = () => (
    <Provider store={store}>
      <MemoryRouter>
        <FinancialReportListPage />
        <CaptureNavigate />
      </MemoryRouter>
    </Provider>
  );
  const view = render(tree());
  return { rerender: () => view.rerender(tree()) };
}

async function waitForCards(count: number) {
  await waitFor(() =>
    expect(screen.getAllByRole('article')).toHaveLength(count),
  );
}

function scrollTo(top: number) {
  act(() => {
    scrollTop = top;
    window.dispatchEvent(new Event('scroll'));
  });
}

const scrollToBottom = () =>
  scrollTo(document.body.offsetHeight - window.innerHeight);

// 応答の処理と、それに続く再描画が済むまで待つ
const settle = () =>
  act(() => new Promise((resolve) => setTimeout(resolve, 200)));

function deferred() {
  let resolve: (response: Response) => void = () => undefined;
  const promise = new Promise<Response>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

it('読み込み中に何度スクロールしても要求は1回で、30件ずつ重複なく増える', async () => {
  const secondPage = deferred();
  reply = (offset) => (offset === 30 ? secondPage.promise : page(offset));
  renderPage();
  await waitForCards(30);

  scrollToBottom();
  scrollToBottom();
  scrollToBottom();
  await settle();
  expect(requestedOffsets).toEqual([0, 30]);

  secondPage.resolve(page(30));
  await waitForCards(60);
  scrollToBottom();
  await waitForCards(90);
  await settle();
  expect(requestedOffsets).toEqual([0, 30, 60]);
  const names = screen.getAllByRole('article').map((card) => card.textContent);
  expect(new Set(names).size).toBe(90);
});

it.each([
  [
    'HTTPのエラー',
    () => new Response('Internal Server Error', { status: 500 }),
  ],
  ['通信の失敗', () => Promise.reject(new TypeError('Failed to fetch'))],
  ['GraphQLのエラー', () => json({ errors: [{ message: 'Internal error' }] })],
])(
  '追加読込が%sで失敗したら、自動では送り直さず、失敗を表示する',
  async (_kind, failure) => {
    reply = (offset) => (offset === 0 ? page(0) : failure());
    const view = renderPage();
    await waitForCards(30);

    scrollToBottom();
    expect((await screen.findByRole('alert')).textContent).toBe(failureMessage);
    expect(screen.queryByRole('progressbar')).toBeNull();
    // 最下部に留まったままのスクロールや再描画では送り直さない
    scrollTo(scrollTop - 100);
    scrollToBottom();
    view.rerender();
    await settle();
    expect(requestedOffsets).toEqual([0, 30]);
    expect(screen.getAllByRole('article')).toHaveLength(30);
  },
);

it('失敗した後、利用者が最下部から離れて戻ったら、同じoffsetから読み直し、続きも読み込める', async () => {
  let secondPageFails = true;
  reply = (offset) =>
    offset === 30 && secondPageFails
      ? new Response('Bad Gateway', { status: 502 })
      : page(offset);
  renderPage();
  await waitForCards(30);
  scrollToBottom();
  await screen.findByRole('alert');

  secondPageFails = false;
  // 読み込みの範囲（一覧の下端から250px）より上へ離れるだけでは送らない
  scrollTo(scrollTop - 250);
  await settle();
  expect(requestedOffsets).toEqual([0, 30]);
  scrollToBottom();
  await waitForCards(60);
  expect(screen.queryByRole('alert')).toBeNull();
  scrollToBottom();
  await waitForCards(90);
  await settle();
  expect(requestedOffsets).toEqual([0, 30, 30, 60]);
});

it('総件数がページサイズの倍数で最後の応答が空のとき、同じoffsetを2回要求しない', async () => {
  reply = (offset) => page(offset, offset === 0 ? pageSize : 0);
  renderPage();
  await waitForCards(30);

  scrollToBottom();
  await waitFor(() => expect(screen.queryByRole('progressbar')).toBeNull());
  await settle();
  expect(requestedOffsets).toEqual([0, 30]);
  expect(screen.queryByRole('alert')).toBeNull();
});

it('検索条件を切り替えた後に前の条件の追加読込が失敗しても、切り替えた後の一覧に失敗を表示しない', async () => {
  const staleSecondPage = deferred();
  reply = (offset, variables) => {
    if (variables.stockCodes) {
      return page(0, 5);
    }
    return offset === 30 ? staleSecondPage.promise : page(offset);
  };
  renderPage();
  await waitForCards(30);
  scrollToBottom();
  await waitFor(() => expect(requestedOffsets).toEqual([0, 30]));

  act(() => navigate('/?stock-codes=7203'));
  await waitForCards(5);
  staleSecondPage.resolve(new Response('Bad Gateway', { status: 502 }));
  await settle();
  expect(screen.queryByRole('alert')).toBeNull();
  expect(screen.getAllByRole('article')).toHaveLength(5);
  expect(requestedOffsets).toEqual([0, 30, 0]);
});
