import React from 'react';
import { cleanup, render, screen, within } from '@testing-library/react';
import type { FinancialReport } from '../api/types';
import { FinancialIndicators } from './FinancialIndicators';

const available = (
  value: number,
): FinancialReport['financialIndicators']['roe'] => ({
  value,
  status: 'AVAILABLE',
});
const data: FinancialReport['financialIndicators'] = {
  roe: available(0.16),
  roa: available(0.064),
  netProfitMargin: available(0.08),
  assetTurnover: available(0.8),
  financialLeverage: available(2.5),
};

afterEach(cleanup);

it('ROE・ROAと3つの分類、分解する数値・記号を表示する', () => {
  render(<FinancialIndicators indicators={data} />);
  const roe = within(screen.getByRole('group', { name: 'ROE' }));
  const roa = within(screen.getByRole('group', { name: 'ROA' }));
  expect(roe.getByLabelText('ROE：16.0%')).toBeTruthy();
  expect(roa.getByLabelText('ROA：6.4%')).toBeTruthy();
  expect(roe.getByText('0.80回')).toBeTruthy();
  expect(roe.getByText('2.50倍')).toBeTruthy();
  expect(roe.getAllByText('×')).toHaveLength(2);
  expect(roa.getAllByText('×')).toHaveLength(1);
  expect(roe.getByText('=')).toBeTruthy();
  ['収益性', '効率性', '健全性'].forEach((text) =>
    expect(screen.getByText(text)).toBeTruthy(),
  );
  expect(screen.queryByRole('link')).toBeNull();
});

it('欠損は「データなし」、対象外のセルだけ「—」にし、記号は残す', () => {
  const missing = { value: null, status: 'MISSING_DATA' as const };
  render(
    <FinancialIndicators
      indicators={{
        roe: missing,
        roa: missing,
        netProfitMargin: missing,
        assetTurnover: missing,
        financialLeverage: missing,
      }}
    />,
  );
  expect(screen.getAllByText('データなし')).toHaveLength(7);
  expect(screen.getAllByText('—')).toHaveLength(1);
  expect(screen.getAllByText('=')).toHaveLength(2);
  expect(screen.getAllByText('×')).toHaveLength(3);
  expect(screen.queryByText('対象外')).toBeNull();
});

it('算出不可を欠損と区別し、算出できるROAを残す', () => {
  const invalid = { value: null, status: 'NOT_CALCULABLE' as const };
  render(
    <FinancialIndicators
      indicators={{ ...data, roe: invalid, financialLeverage: invalid }}
    />,
  );
  expect(screen.getAllByText('算出不可')).toHaveLength(2);
  expect(screen.getByLabelText('ROA：6.4%')).toBeTruthy();
  expect(screen.queryByText('データなし')).toBeNull();
});

it('ゼロ利益・赤字は欠損として表示しない', () => {
  render(
    <FinancialIndicators
      indicators={{ ...data, roe: available(0), roa: available(-0.064) }}
    />,
  );
  expect(screen.getByLabelText('ROE：0.0%')).toBeTruthy();
  expect(screen.getByLabelText('ROA：-6.4%')).toBeTruthy();
  expect(screen.queryByText('データなし')).toBeNull();
});
