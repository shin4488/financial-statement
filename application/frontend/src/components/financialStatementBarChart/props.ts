import { childrenComponentType } from '@/constants/types';

export interface FinancialStatementBarChartProps<
  T extends unknown[] | undefined,
> {
  children: childrenComponentType;
  data: T;
  tooltipFormatter: (
    value: string | number | (string | number)[],
    name: string | number,
  ) => [string, string];
}
