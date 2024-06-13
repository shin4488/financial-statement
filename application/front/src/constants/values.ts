export const financialStatementOffsetUnit = 30;

export const barChartWidth = '90%';
export const barChartHeight = 400;

export const tooltipStyle = {
  backgroundColor: '#F6F4EB',
  opacity: '0.8',
  padding: '10px',
};

export const stackLabelListFillColor = '#FFF';

export type CashFlowTypeValue =
  | 'none'
  | 'healthy'
  | 'active'
  | 'stable'
  | 'improving'
  | 'competitive'
  | 'restructuring'
  | 'reconsidering'
  | 'rescuing';

interface CashFlowType {
  raises_or_falls: string[];
  text: string;
  value: CashFlowTypeValue;
}

export const cashFlowTypes: CashFlowType[] = [
  { raises_or_falls: [], text: '指定なし', value: 'none' },
  { raises_or_falls: ['↑', '↓', '↓'], text: '健全型', value: 'healthy' },
  { raises_or_falls: ['↑', '↓', '↑'], text: '積極型', value: 'active' },
  { raises_or_falls: ['↑', '↑', '↑'], text: '安定型', value: 'stable' },
  { raises_or_falls: ['↑', '↑', '↓'], text: '改善型', value: 'improving' },
  {
    raises_or_falls: ['↓', '↓', '↑'],
    text: '勝負型',
    value: 'competitive',
  },
  {
    raises_or_falls: ['↓', '↑', '↓'],
    text: 'リストラ型',
    value: 'restructuring',
  },
  {
    raises_or_falls: ['↓', '↓', '↓'],
    text: '大幅見直し型',
    value: 'reconsidering',
  },
  { raises_or_falls: ['↓', '↑', '↑'], text: '救済型', value: 'rescuing' },
];

type NumberSign = 'POSITIVE' | 'NEGATIVE';

interface CashFlowTypeRequest {
  operatingActivitiesCashFlowSign: NumberSign | null;
  investingActivitiesCashFlowSign: NumberSign | null;
  financingActivitiesCashFlowSign: NumberSign | null;
}

export const cashFlowTypeRequestMap: Record<
  CashFlowTypeValue,
  CashFlowTypeRequest
> = {
  none: {
    operatingActivitiesCashFlowSign: null,
    investingActivitiesCashFlowSign: null,
    financingActivitiesCashFlowSign: null,
  },
  healthy: {
    operatingActivitiesCashFlowSign: 'POSITIVE',
    investingActivitiesCashFlowSign: 'NEGATIVE',
    financingActivitiesCashFlowSign: 'NEGATIVE',
  },
  active: {
    operatingActivitiesCashFlowSign: 'POSITIVE',
    investingActivitiesCashFlowSign: 'NEGATIVE',
    financingActivitiesCashFlowSign: 'POSITIVE',
  },
  stable: {
    operatingActivitiesCashFlowSign: 'POSITIVE',
    investingActivitiesCashFlowSign: 'POSITIVE',
    financingActivitiesCashFlowSign: 'POSITIVE',
  },
  improving: {
    operatingActivitiesCashFlowSign: 'POSITIVE',
    investingActivitiesCashFlowSign: 'POSITIVE',
    financingActivitiesCashFlowSign: 'NEGATIVE',
  },
  competitive: {
    operatingActivitiesCashFlowSign: 'NEGATIVE',
    investingActivitiesCashFlowSign: 'NEGATIVE',
    financingActivitiesCashFlowSign: 'POSITIVE',
  },
  restructuring: {
    operatingActivitiesCashFlowSign: 'NEGATIVE',
    investingActivitiesCashFlowSign: 'POSITIVE',
    financingActivitiesCashFlowSign: 'NEGATIVE',
  },
  reconsidering: {
    operatingActivitiesCashFlowSign: 'NEGATIVE',
    investingActivitiesCashFlowSign: 'NEGATIVE',
    financingActivitiesCashFlowSign: 'NEGATIVE',
  },
  rescuing: {
    operatingActivitiesCashFlowSign: 'NEGATIVE',
    investingActivitiesCashFlowSign: 'POSITIVE',
    financingActivitiesCashFlowSign: 'POSITIVE',
  },
};
