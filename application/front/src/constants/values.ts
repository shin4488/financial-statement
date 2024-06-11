export const financialStatementOffsetUnit = 30;

export const barChartWidth = '90%';
export const barChartHeight = 400;

export const tooltipStyle = {
  backgroundColor: '#F6F4EB',
  opacity: '0.8',
  padding: '10px',
};

export const stackLabelListFillColor = '#FFF';

export const cashFlowFilterItems = [
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
