import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import type { FinancialReport } from '../api/types';
import { amountLabel, FreeCashFlowChart } from '@/shared/financialCharts';

type Trend = FinancialReport['freeCashFlowTrend'];

const points: Trend['points'] = [2021, 2022, 2023, 2024, 2025].map((year) => ({
  year,
  fiscalYearStartDate: `${year - 1}-04-01`,
  fiscalYearEndDate: `${year}-03-31`,
  operatingCf: 15_000_000,
  investingCf: -3_000_000,
  amount: 12_000_000,
}));

beforeEach(() => {
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

// グラフの幅の監視から、指定した幅を渡す
function stubChartWidth(width: number) {
  vi.stubGlobal(
    'ResizeObserver',
    class {
      constructor(
        private callback: (
          entries: { contentRect: { width: number; height: number } }[],
        ) => void,
      ) {}
      observe() {
        this.callback([{ contentRect: { width, height: 305 } }]);
      }
      unobserve() {}
      disconnect() {}
    },
  );
}

it('金額をカード共通の百万円単位で表示し、100万円未満も0と誤表示しない', () => {
  expect(amountLabel(12_000_000)).toBe('12');
  expect(amountLabel(-4_000_000)).toBe('-4');
  expect(amountLabel(500_000)).toBe('0.5');
  expect(amountLabel(-1_000)).toBe('-0.001');
  expect(amountLabel(0)).toBe('0');
});

it('一部の年が欠けても他の年を残し、欠損を0円と区別する', () => {
  const trend: Trend = {
    renderable: true,
    note: null,
    points: points.map((point) =>
      point.year === 2023
        ? { ...point, investingCf: null, amount: null }
        : point,
    ),
  };

  render(<FreeCashFlowChart trend={trend} />);

  expect(
    screen.getByRole('region', { name: /2023年：データなし/ }),
  ).toBeTruthy();
  expect(screen.getByRole('region', { name: /2025年：12百万円/ })).toBeTruthy();
  expect(screen.queryByText('過去5年のデータがありません')).toBeNull();
});

it('狭いカードで欠損年があっても、各年の金額をその年の棒の位置に表示する', () => {
  // 3枚並びのカードと同じ幅を、グラフの幅の監視から渡す
  const chartWidth = 371;
  stubChartWidth(chartWidth);
  const amounts = [null, 11_000_000, 22_000_000, null, 44_000_000];
  const trend: Trend = {
    renderable: true,
    note: null,
    points: points.map((point, index) => ({
      ...point,
      investingCf: amounts[index] == null ? null : point.investingCf,
      amount: amounts[index],
    })),
  };

  const { container } = render(<FreeCashFlowChart trend={trend} />);

  const labels = [...container.querySelectorAll('text')]
    .filter((text) => !text.closest('.recharts-cartesian-axis'))
    .filter((text) => /^-?[\d.,]+$/.test(text.textContent ?? ''))
    .map((text) => ({
      label: text.textContent,
      x: Number(text.getAttribute('x')),
    }));
  const slotCenter = (index: number) =>
    4 + (index + 0.5) * ((chartWidth - 8) / amounts.length);
  expect(labels).toHaveLength(3);
  expect(labels.find(({ label }) => label === '11')?.x).toBeCloseTo(
    slotCenter(1),
  );
  expect(labels.find(({ label }) => label === '22')?.x).toBeCloseTo(
    slotCenter(2),
  );
  expect(labels.find(({ label }) => label === '44')?.x).toBeCloseTo(
    slotCenter(4),
  );
});

it('全期間欠損時は説明を一文だけ表示する', () => {
  render(
    <FreeCashFlowChart
      trend={{
        renderable: false,
        note: '過去5年のデータがありません',
        points: points.map((point) => ({
          ...point,
          operatingCf: null,
          amount: null,
        })),
      }}
    />,
  );

  expect(screen.getByText('過去5年のデータがありません')).toBeTruthy();
  expect(screen.queryByText(/営業CF・投資CFを確認できない/)).toBeNull();
  expect(screen.queryByText('2023年：データなし')).toBeNull();
});

it('連結と単体が混在する場合は切替の注記を表示する', () => {
  render(
    <FreeCashFlowChart
      trend={{
        renderable: true,
        note: '連結区分：2021～2024年 単体 → 2025年 連結',
        points,
      }}
    />,
  );

  expect(
    screen.getByText('連結区分：2021～2024年 単体 → 2025年 連結'),
  ).toBeTruthy();
});
