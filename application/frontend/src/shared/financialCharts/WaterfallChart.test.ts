import { toWaterfallRows } from './WaterfallChart';
import type { WaterfallStep } from './types';

const step = (key: string, amount: number, kind: string): WaterfallStep => ({
  key,
  label: key,
  amount,
  kind,
});

describe('toWaterfallRows', () => {
  it('balanceは0起点、flowは直前の累積位置から増減分を浮かせる', () => {
    const rows = toWaterfallRows([
      step('cashBegin', 100, 'balance'),
      step('operating', 30, 'flow'),
      step('investing', -50, 'flow'),
      step('cashEnd', 80, 'balance'),
    ]);
    expect(
      rows.map(({ base, span, value }) => ({ base, span, value })),
    ).toEqual([
      { base: 0, span: 100, value: 100 },
      { base: 100, span: 30, value: 30 },
      { base: 80, span: 50, value: -50 }, // 減少はbase=下端、span=絶対値で下向きに見せる
      { base: 0, span: 80, value: 80 },
    ]);
  });

  it('期末残高は累積でなく実際の残高で描く（為替換算差額で累積と期末が一致しない書類を吸収する）', () => {
    const rows = toWaterfallRows([
      step('cashBegin', 100, 'balance'),
      step('operating', 30, 'flow'),
      step('cashEnd', 125, 'balance'), // 累積は130だが換算差額-5で125
    ]);
    expect(rows[2]).toMatchObject({ base: 0, span: 125, value: 125 });
  });

  it('累積が負に落ちる巨額マイナスでも下向きに正しく描ける', () => {
    const rows = toWaterfallRows([
      step('cashBegin', 100, 'balance'),
      step('operating', -300, 'flow'),
    ]);
    expect(rows[1]).toMatchObject({ base: -200, span: 300, value: -300 });
  });
});
