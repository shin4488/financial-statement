import { periodTickFontSize } from './FreeCashFlowChart';

describe('フリーCFの年/月ラベル', () => {
  it('短い月は16pxで表示し、狭い画面の12月は5年分が収まる大きさにする', () => {
    const june = ['2022/6', '2023/6', '2024/6', '2025/6', '2026/6'];
    const december = ['2022/12', '2023/12', '2024/12', '2025/12', '2026/12'];

    expect(periodTickFontSize(june, 272)).toBe(16);
    expect(periodTickFontSize(december, 272)).toBe(14);
    expect(periodTickFontSize(december, 340)).toBe(16);
  });
});
