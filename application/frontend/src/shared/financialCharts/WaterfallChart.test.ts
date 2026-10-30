import {
  layoutValueLabels,
  stepTickFontSize,
  toWaterfallRows,
  waterfallDomain,
} from './WaterfallChart';
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

describe('stepTickFontSize', () => {
  const cashFlowLabels = ['期首残', '営業CF', '投資CF', '財務CF', '期末残'];
  // 最も幅をとる「投資CF」を、16pxのRobotoでブラウザ描画したときの幅（55px）
  const widestLabelEm = 55 / 16;

  it('幅に余裕があれば16pxで表示する', () => {
    expect(stepTickFontSize(cashFlowLabels, 736)).toBe(16);
  });

  it('狭い幅では、全区分のラベルが1区分の幅に収まるまで縮める', () => {
    // 293pxは16pxのままでは目盛りが重なる幅
    for (const chartWidth of [211, 293]) {
      const fontSize = stepTickFontSize(cashFlowLabels, chartWidth);
      expect(fontSize).toBeLessThan(16);
      expect(fontSize * widestLabelEm).toBeLessThanOrEqual(
        (chartWidth - 10) / cashFlowLabels.length,
      );
    }
  });

  it('読めなくならないよう10pxより小さくしない', () => {
    expect(stepTickFontSize(cashFlowLabels, 120)).toBe(10);
  });
});

describe('waterfallDomain', () => {
  // 期待値は、表示範囲を自動にしたときにrechartsが決める範囲（0を含む5本の目盛りが切りのよい値になる範囲）
  it('0から最も高いバーの上端までを、切りのよい目盛りの値まで広げる', () => {
    expect(
      waterfallDomain(
        toWaterfallRows([
          step('cashBegin', 100, 'balance'),
          step('operating', 30, 'flow'),
          step('cashEnd', 120, 'balance'),
        ]),
      ),
    ).toEqual([0, 140]);
    expect(
      waterfallDomain(
        toWaterfallRows([
          step('cashBegin', 10_000, 'balance'),
          step('operating', 3_000, 'flow'),
          step('investing', -2_000, 'flow'),
        ]),
      ),
    ).toEqual([0, 14_000]);
  });

  it('累積が負になれば0より下も含める', () => {
    expect(
      waterfallDomain(
        toWaterfallRows([
          step('cashBegin', 100, 'balance'),
          step('operating', -300, 'flow'),
        ]),
      ),
    ).toEqual([-200, 200]);
  });
});

describe('layoutValueLabels', () => {
  const million = 1_000_000;
  const cashFlow = (amounts: number[]) =>
    toWaterfallRows(
      ['cashBegin', 'operating', 'investing', 'financing', 'cashEnd'].map(
        (key, index) =>
          step(
            key,
            amounts[index] * million,
            index === 0 || index === 4 ? 'balance' : 'flow',
          ),
      ),
    );
  // ブラウザで16pxの金額を描いて測った文字幅（「10,000」は50px、「8,982,404」は73px）から求めた1文字の幅
  const labelWidth = (label: string, fontSize: number) =>
    ([...label].filter((char) => char === ',').length * 5 +
      [...label].filter((char) => char !== ',').length * 9) *
    (fontSize / 16);
  const boxes = (
    rows: ReturnType<typeof toWaterfallRows>,
    labels: string[],
    chartWidth: number,
  ) => {
    const layout = layoutValueLabels(
      rows,
      waterfallDomain(rows),
      chartWidth,
      400,
    );
    return {
      layout,
      boxes: layout.positions.map(({ x, y }, index) => {
        const width = labelWidth(labels[index], layout.fontSize);
        return {
          left: x - width / 2,
          right: x + width / 2,
          top: y - layout.fontSize,
          bottom: y,
        };
      }),
    };
  };
  const overlaps = (
    a: { left: number; right: number; top: number; bottom: number },
    b: typeof a,
  ) =>
    a.left < b.right &&
    b.left < a.right &&
    a.top < b.bottom &&
    b.top < a.bottom;

  it('幅に余裕があれば16pxのまま、各区分の中央でバーの上端の5px上に置く', () => {
    const rows = cashFlow([10_000, 3_000, -2_000, -1_000, 5_000]);
    const layout = layoutValueLabels(rows, [0, 13_000 * million], 736, 400);
    expect(layout.fontSize).toBe(16);
    // 描画域は上端28px〜下端（400 - 下の余白5px - X軸30px）、1区分は(736 - 左右の余白10px) / 5
    const plotHeight = 400 - 5 - 30 - 28;
    const yOf = (top: number) =>
      28 + ((13_000 - top) / 13_000) * plotHeight - 5;
    expect(layout.positions).toEqual([
      { x: 5 + 145.2 * 0.5, y: yOf(10_000) },
      { x: 5 + 145.2 * 1.5, y: yOf(13_000) },
      { x: 5 + 145.2 * 2.5, y: yOf(13_000) },
      { x: 5 + 145.2 * 3.5, y: yOf(11_000) },
      { x: 5 + 145.2 * 4.5, y: yOf(5_000) },
    ]);
  });

  it('狭い幅では、桁の多い金額も1区分の幅に収まるまで文字を小さくする', () => {
    const amounts = [8_982_404, 3_695_939, -4_000_000, -1_500_000, 7_178_343];
    const labels = [
      '8,982,404',
      '3,695,939',
      '-4,000,000',
      '-1,500,000',
      '7,178,343',
    ];
    const { layout, boxes: placed } = boxes(cashFlow(amounts), labels, 292);
    expect(layout.fontSize).toBeLessThan(16);
    const slotWidth = (292 - 10) / 5;
    placed.forEach((box) =>
      expect(box.right - box.left).toBeLessThanOrEqual(slotWidth),
    );
  });

  it('10pxでも収まらないときは、隣のラベルと重ならないよう上へずらし、グラフの上端からはみ出させない', () => {
    // 営業CFと投資CFのバーの上端が同じ高さになり、ラベルが横にも縦にも重なる
    const amounts = [8_982_404, 3_695_939, -4_000_000, -1_500_000, 7_178_343];
    const labels = [
      '8,982,404',
      '3,695,939',
      '-4,000,000',
      '-1,500,000',
      '7,178,343',
    ];
    const { layout, boxes: placed } = boxes(cashFlow(amounts), labels, 211);
    expect(layout.fontSize).toBe(10);
    placed.forEach((a, i) =>
      placed.slice(i + 1).forEach((b) => expect(overlaps(a, b)).toBe(false)),
    );
    expect(placed[2].bottom).toBeLessThan(placed[1].top + 1);
    placed.forEach((box) => expect(box.top).toBeGreaterThanOrEqual(0));
  });

  it('グラフの左右の端のラベルは、桁が多くてもグラフの外にはみ出さない', () => {
    // 10pxでも1区分より広く、各区分の中央に置くと端のラベルがはみ出す
    const labels = ['12,345,678', '3,000', '-2,000', '-1,000', '12,346,678'];
    const { boxes: placed } = boxes(
      cashFlow([12_345_678, 3_000, -2_000, -1_000, 12_346_678]),
      labels,
      193,
    );
    placed.forEach((box) => {
      expect(box.left).toBeGreaterThanOrEqual(0);
      expect(box.right).toBeLessThanOrEqual(193);
    });
  });
});
