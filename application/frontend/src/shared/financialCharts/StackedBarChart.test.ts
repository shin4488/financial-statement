import { toStackRows } from './StackedBarChart';
import type { Segment, StackChart } from './types';

const seg = (key: string, amount: number, ratio: number | null): Segment => ({
  key,
  label: `${key}のラベル`,
  amount,
  signedAmount: amount,
  ratio,
  colorRole: 'asset1',
});

describe('toStackRows', () => {
  const chart: StackChart = {
    renderable: true,
    bars: [
      {
        label: '借方',
        segments: [seg('currentAssets', 60, 60), seg('fixedAssets', 40, 40)],
      },
      {
        label: '貸方',
        segments: [seg('liabilities', 70, 70), seg('spacer', 30, null)],
      },
    ],
  };

  it('列はバー出現順・セグメント出現順の和集合になる（APIの配列順序が描画順の契約）', () => {
    const { columns } = toStackRows(chart);
    expect(columns.map((c) => c.key)).toEqual([
      'currentAssets',
      'fixedAssets',
      'liabilities',
      'spacer',
    ]);
  });

  it('バーに存在しないキーの列値はundefinedになり、そのバーには何も描かれない', () => {
    const { rows } = toStackRows(chart);
    expect(rows[0].currentAssets).toBe(60);
    expect(rows[0].liabilities).toBeUndefined();
    expect(rows[1].liabilities).toBe(70);
  });

  it('ratioがnullのセグメント（spacer等）はRatioフィールド自体を作らず、ラベルが描かれない', () => {
    const { rows } = toStackRows(chart);
    expect(rows[1].liabilitiesRatio).toBe(70);
    expect('spacerRatio' in rows[1]).toBe(false);
  });

  it('ツールチップ用のセグメントメタを__segmentsからキーで引ける', () => {
    const { rows } = toStackRows(chart);
    expect(rows[0].__segments.currentAssets.label).toBe(
      'currentAssetsのラベル',
    );
  });
});
