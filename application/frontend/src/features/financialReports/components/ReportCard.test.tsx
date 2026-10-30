import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { act, cleanup, render, screen } from '@testing-library/react';
import { ReportCard } from './ReportCard';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import type { FinancialReport } from '../api/types';

vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
}));

const segment = (key: string, label: string, ratio: number) => ({
  key,
  label,
  amount: ratio,
  signedAmount: ratio,
  ratio,
  colorRole: 'asset1',
  tooltipLabel: null,
});
const unavailable = { renderable: false, note: null };

const report = (companyName: string): FinancialReport => ({
  id: companyName,
  stockCode: '1234',
  companyName,
  fiscalYearStartDate: '2025-04-01',
  fiscalYearEndDate: '2026-03-31',
  accountingStandard: 'jgaap',
  consolidationType: 'consolidated',
  financialIndicators: {
    roe: { value: null, status: 'MISSING_DATA', source: null },
    roa: { value: null, status: 'MISSING_DATA' },
    netProfitMargin: { value: null, status: 'MISSING_DATA' },
    assetTurnover: { value: null, status: 'MISSING_DATA' },
    financialLeverage: { value: null, status: 'MISSING_DATA' },
  },
  balanceSheet: {
    renderable: true,
    note: null,
    bars: [
      { label: '借方', segments: [segment('currentAssets', '流動資産', 100)] },
    ],
  },
  profitLoss: {
    renderable: true,
    note: null,
    bars: [{ label: '収益', segments: [segment('revenue', '売上高', 100)] }],
  },
  cashFlow: { ...unavailable, steps: [] },
  freeCashFlowTrend: { ...unavailable, points: [] },
});

// 画面に見えてきたことを、IntersectionObserverの代わりにテストから知らせる
let observed: { callback: IntersectionObserverCallback; element: Element }[] =
  [];
function showInViewport(card: HTMLElement) {
  act(() => {
    observed
      .filter(({ element }) => element === card)
      .forEach(({ callback, element }) =>
        callback(
          [
            {
              target: element,
              isIntersecting: true,
            } as IntersectionObserverEntry,
          ],
          {} as IntersectionObserver,
        ),
      );
  });
}

// 時間を進める。1フレームは約16ms
function advance(ms: number) {
  act(() => {
    vi.advanceTimersByTime(ms);
  });
}

beforeEach(() => {
  vi.useFakeTimers({
    toFake: [
      'setTimeout',
      'clearTimeout',
      'requestAnimationFrame',
      'cancelAnimationFrame',
    ],
  });
  observed = [];
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      constructor(private callback: IntersectionObserverCallback) {}
      observe(element: Element) {
        observed.push({ callback: this.callback, element });
      }
      disconnect() {
        observed = observed.filter(
          ({ callback }) => callback !== this.callback,
        );
      }
    },
  );
  // jsdomは要素の大きさを計算しないため、グラフを描ける大きさを、要素の寸法と大きさの監視の両方から渡す
  vi.spyOn(Element.prototype, 'clientWidth', 'get').mockReturnValue(400);
  vi.spyOn(Element.prototype, 'clientHeight', 'get').mockReturnValue(400);
  vi.stubGlobal(
    'ResizeObserver',
    class {
      constructor(
        private callback: (
          entries: { contentRect: { width: number; height: number } }[],
        ) => void,
      ) {}
      observe() {
        this.callback([{ contentRect: { width: 400, height: 400 } }]);
      }
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  // 順番待ちの処理を最後まで進め、次のテストに持ち越さない
  act(() => {
    vi.runOnlyPendingTimers();
  });
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

// 会社名ごとに、画面の上端からの位置を決めてカードを並べる
function renderCards(tops: Record<string, number>) {
  vi.spyOn(Element.prototype, 'getBoundingClientRect').mockImplementation(
    function (this: Element) {
      const name = Object.keys(tops).find((key) =>
        this.textContent?.startsWith(key),
      );
      const top = name ? tops[name] : 0;
      return {
        x: 0,
        y: top,
        top,
        left: 0,
        right: 400,
        bottom: top + 600,
        width: 400,
        height: 600,
        toJSON: () => ({}),
      };
    },
  );
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay: false } },
  });
  render(
    <Provider store={store}>
      {Object.keys(tops).map((name) => (
        <ReportCard key={name} report={report(name)} />
      ))}
    </Provider>,
  );
  return Object.fromEntries(
    Object.keys(tops).map((name) => [
      name,
      screen.getByText(name).closest('.MuiCard-root') as HTMLElement,
    ]),
  );
}

// 描いたグラフにだけ、区分のラベルが出る
const drawn = (card: HTMLElement) => card.textContent?.includes('流動資産');
const below = (screens: number) => window.innerHeight * screens;

it('画面と、そのすぐ下（画面の高さの半分まで）にあるカードは、最初の表示からグラフを描く', () => {
  const cards = renderCards({
    見える: 0,
    すぐ下: below(1.2),
    離れた: below(3),
  });
  expect([
    drawn(cards['見える']),
    drawn(cards['すぐ下']),
    drawn(cards['離れた']),
  ]).toEqual([true, true, false]);
});

it('画面から離れたカードは、置いた順に1枚ずつグラフを描く', () => {
  const cards = renderCards({ 一枚目: below(2), 二枚目: below(3) });
  expect([drawn(cards['一枚目']), drawn(cards['二枚目'])]).toEqual([
    false,
    false,
  ]);

  advance(0);
  expect([drawn(cards['一枚目']), drawn(cards['二枚目'])]).toEqual([
    true,
    false,
  ]);

  advance(20);
  expect([drawn(cards['一枚目']), drawn(cards['二枚目'])]).toEqual([
    true,
    true,
  ]);
});

it('順番を待つ間に画面に見えてきたカードは、順番を待たずにグラフを描く', () => {
  const cards = renderCards({ 一枚目: below(2), 二枚目: below(3) });

  showInViewport(cards['二枚目']);
  expect([drawn(cards['一枚目']), drawn(cards['二枚目'])]).toEqual([
    false,
    true,
  ]);
});
