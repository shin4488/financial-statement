import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import {
  MemoryRouter,
  NavigateFunction,
  Route,
  Routes,
  useLocation,
  useNavigate,
} from 'react-router-dom';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import FinancialReportListPage from './FinancialReportListPage';
import { financialReportsClient } from './apolloClient';
import type { FinancialReport } from './api/types';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import { trackEvent } from '@/plugins/firebase/analytics';

// カードの中身はこのテストの対象外。表示された企業を数えられるよう、企業名だけを出す
vi.mock('./components/ReportCard', () => ({
  ReportCard: ({ report }: { report: FinancialReport }) => (
    <article>{report.companyName}</article>
  ),
}));
// 追加読込の結果を処理し終えたことを、計測の呼び出しで知る
vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
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

// APIの代わりに、要求されたoffsetと証券コードを記録して、テストごとに決めた応答を返す。
// 本物の通信と同じく応答は別のタスクで返す（送り直しが止まらない不具合が戻っても、待ち時間の上限でテストが終わるようにする）。
type Variables = { offset: number; stockCodes: string[] | null };
let reply: (
  offset: number,
  variables: Variables,
) => Response | Promise<Response>;
let requestedOffsets: number[] = [];
let requestedStockCodes: (string[] | null)[] = [];

// jsdomはレイアウトを計算しないため、カード1枚の高さと縦のスクロール位置をブラウザの代わりに与える。
// 一覧はページの先頭から始まり、要素の高さは中のカードの枚数で決まるものとする
const cardHeight = 400;
let scrollTop = 0;

beforeEach(() => {
  requestedOffsets = [];
  requestedStockCodes = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const { variables } = JSON.parse(String(init?.body));
      requestedOffsets.push(variables.offset);
      requestedStockCodes.push(variables.stockCodes);
      await new Promise((resolve) => setTimeout(resolve, 0));
      return reply(variables.offset, variables);
    }),
  );
  scrollTop = 0;
  Object.defineProperty(window, 'pageYOffset', {
    configurable: true,
    get: () => scrollTop,
  });
  Object.defineProperty(window, 'scrollY', {
    configurable: true,
    get: () => scrollTop,
  });
  // jsdomはwindow.scrollToを持たない。一覧は「戻る」で戻ったときに位置を戻すため呼ぶ
  vi.spyOn(window, 'scrollTo').mockImplementation(() => undefined);
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
  vi.mocked(trackEvent).mockClear();
  vi.mocked(window.scrollTo).mockRestore();
  await financialReportsClient.clearStore();
});

// 検索条件の切り替え（URLの変更）をテストから行う
let navigate: NavigateFunction = () => undefined;
function CaptureNavigate() {
  navigate = useNavigate();
  return null;
}

function CurrentStockCodes() {
  const { search } = useLocation();
  return (
    <output data-testid="url-stock-codes">
      {new URLSearchParams(search).get('stock-codes')}
    </output>
  );
}

function renderPage(url = '/') {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
  });
  const tree = () => (
    <Provider store={store}>
      <MemoryRouter initialEntries={[url]}>
        <FinancialReportListPage />
        <CaptureNavigate />
        <CurrentStockCodes />
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

// 保留していた追加読込を失敗させ、ページがその失敗を処理して描画し終えるまで待つ
async function failPendingRequest(pending: ReturnType<typeof deferred>) {
  await act(async () => {
    pending.resolve(new Response('Bad Gateway', { status: 502 }));
    await vi.waitFor(() =>
      expect(trackEvent).toHaveBeenCalledWith('report_load_more', {
        result_status: 'error',
      }),
    );
  });
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
  // 読み込みの範囲（一覧の下端から250px）より上へ離れると、失敗の表示を消して読み込み待ちに戻る。離れるだけでは送らない
  scrollTo(scrollTop - 250);
  await waitFor(() => expect(screen.queryByRole('alert')).toBeNull());
  expect(screen.getByRole('progressbar')).toBeDefined();
  expect(requestedOffsets).toEqual([0, 30]);
  scrollToBottom();
  await waitForCards(60);
  scrollToBottom();
  await waitForCards(90);
  await settle();
  expect(requestedOffsets).toEqual([0, 30, 30, 60]);
});

it('追加読込の途中で最下部から離れ、その後に失敗したときも、最下部へ戻ったら読み直す', async () => {
  const failingSecondPage = deferred();
  let secondPageFails = true;
  reply = (offset) =>
    offset === 30 && secondPageFails ? failingSecondPage.promise : page(offset);
  renderPage();
  await waitForCards(30);
  scrollToBottom();
  await waitFor(() => expect(requestedOffsets).toEqual([0, 30]));

  scrollTo(scrollTop - 500);
  await failPendingRequest(failingSecondPage);
  secondPageFails = false;
  // 失敗した後はスクロールせず、最下部へ一度に移る（Endキーなど）
  scrollToBottom();
  await waitForCards(60);
  expect(requestedOffsets).toEqual([0, 30, 30]);
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
  await failPendingRequest(staleSecondPage);
  expect(screen.queryByRole('alert')).toBeNull();
  expect(screen.getAllByRole('article')).toHaveLength(5);
  expect(requestedOffsets).toEqual([0, 30, 0]);
});

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

it('静的ページへ移ってブラウザの「戻る」で一覧に戻ると、離れたときのスクロール位置に戻す。リンクで一覧を開いたときは戻さない', async () => {
  reply = (offset) => page(offset);
  const scrollToPosition = vi.mocked(window.scrollTo);
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
  });
  render(
    <Provider store={store}>
      <MemoryRouter>
        <Routes>
          <Route path="/guide" element={<p>財務三表の読み方</p>} />
          <Route path="*" element={<FinancialReportListPage />} />
        </Routes>
        <CaptureNavigate />
      </MemoryRouter>
    </Provider>,
  );
  await waitForCards(30);
  // MemoryRouterの最初の履歴は、どのテストでも同じキーのため、前のテストで覚えた位置に戻すことがある。それは見ない
  scrollToPosition.mockClear();
  scrollTo(4000);
  act(() => navigate('/guide'));
  await screen.findByText('財務三表の読み方');
  // 静的ページは先頭から表示する（StaticPageLayout）
  scrollTo(0);

  act(() => navigate(-1));
  await waitForCards(30);
  expect(scrollToPosition).toHaveBeenCalledWith(0, 4000);

  scrollToPosition.mockClear();
  act(() => navigate('/guide'));
  await screen.findByText('財務三表の読み方');
  act(() => navigate('/'));
  await waitForCards(30);
  expect(scrollToPosition).not.toHaveBeenCalled();
});

describe('証券コードの検索', () => {
  beforeEach(() => {
    reply = () => json({ data: { financialReports: [] } });
  });

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
