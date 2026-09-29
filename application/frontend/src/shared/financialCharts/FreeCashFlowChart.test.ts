import {
  amountLabel,
  compactAmountPositions,
  periodTickFontSize,
} from './FreeCashFlowChart';

describe('フリーCFの金額表記', () => {
  it('プラスは符号なし、マイナスだけ符号を付ける', () => {
    expect(amountLabel(12_000_000)).toBe('12');
    expect(amountLabel(-12_000_000)).toBe('-12');
    expect(amountLabel(0)).toBe('0');
  });
});

describe('フリーCFの年/月ラベル', () => {
  it('短い月は16pxで表示し、狭い画面の12月は5年分が収まる大きさにする', () => {
    const june = ['2022/6', '2023/6', '2024/6', '2025/6', '2026/6'];
    const december = ['2022/12', '2023/12', '2024/12', '2025/12', '2026/12'];

    expect(periodTickFontSize(june, 272)).toBe(16);
    expect(periodTickFontSize(december, 272)).toBe(14);
    expect(periodTickFontSize(december, 340)).toBe(16);
  });
});

describe('狭いカードの金額ラベル', () => {
  it('符号が交互に変わる5年でも隣の金額を重ねず、左右に収める', () => {
    const amounts = [
      -329_994_000, -27_021_000, -121_251_000, 39_725_000, -702_466_000,
    ];
    const positions = compactAmountPositions(amounts, [-850, 50], 272);

    expect(positions).toHaveLength(5);
    for (const [index, position] of positions.entries()) {
      const labelWidth = amountLabel(amounts[index]).length * 9;
      expect(position.x).toBeGreaterThanOrEqual(labelWidth / 2);
      expect(position.x).toBeLessThanOrEqual(272 - labelWidth / 2);
      expect(position.y).toBeGreaterThanOrEqual(19);
    }
    expect(Math.abs(positions[2].y - positions[3].y)).toBeGreaterThanOrEqual(
      19,
    );
    expect(Math.abs(positions[3].y - positions[4].y)).toBeGreaterThanOrEqual(
      19,
    );
  });
});
