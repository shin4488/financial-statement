import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import type { FinancialReport } from '../api/types';
import { amountLabel, FreeCashFlowChart } from './FreeCashFlowChart';

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

it('金額をカード共通の百万円単位で表示し、100万円未満も0と誤表示しない', () => {
  expect(amountLabel(12_000_000)).toBe('+12');
  expect(amountLabel(-4_000_000)).toBe('-4');
  expect(amountLabel(500_000)).toBe('+0.5');
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
    screen.getByText('フリーキャッシュフロー＝営業CF＋投資CF'),
  ).toBeTruthy();
  expect(
    screen.getByRole('region', { name: /2023年：データなし/ }),
  ).toBeTruthy();
  expect(screen.queryByText('過去5年のデータがありません')).toBeNull();
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
