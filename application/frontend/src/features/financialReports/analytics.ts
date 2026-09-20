import { ProductParams } from '@/plugins/firebase/analytics';
import { parseCashFlowType, parseStockCodes } from './searchCriteria';

export function searchAnalytics(searchParams: URLSearchParams): ProductParams {
  const stockCount = parseStockCodes(searchParams).length;
  const filtered = parseCashFlowType(searchParams) !== 'none';
  return {
    stock_count: stockCount,
    search_mode: stockCount
      ? filtered
        ? 'combined'
        : 'stock'
      : filtered
      ? 'cash_flow'
      : 'browse',
  };
}
