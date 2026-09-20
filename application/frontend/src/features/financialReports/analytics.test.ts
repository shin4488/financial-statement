import { describe, expect, it } from 'vitest';
import { searchAnalytics } from './analytics';

describe('search telemetry', () => {
  it.each([
    ['', 'browse', 0],
    ['stock-codes=7203,391A', 'stock', 2],
    ['cash-flow-type=healthy', 'cash_flow', 0],
    ['stock-codes=7203&cash-flow-type=healthy', 'combined', 1],
  ])('classifies %s without collecting input', (query, mode, count) => {
    expect(searchAnalytics(new URLSearchParams(query))).toEqual({
      search_mode: mode,
      stock_count: count,
    });
  });
  it('does not leak free-form input', () => {
    expect(
      searchAnalytics(new URLSearchParams('stock-codes=person@example.com')),
    ).toEqual({ search_mode: 'stock', stock_count: 1 });
  });
});
