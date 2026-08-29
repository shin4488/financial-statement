import React from 'react';
import {
  Bar,
  BarChart,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  YAxis,
} from 'recharts';
import {
  colorForRole,
  hiddenRoles,
  stackLabelColor,
  tooltipBackgroundColor,
} from './colorRoles';
import { ChartUnavailable } from './ChartUnavailable';
import { formatAmount } from './formatAmount';
import type { StackChart, Segment } from './types';

// rechartsは「行の配列 * 固定dataKey」を要求するが、こちらは「バーごとに異なるセグメント列」を
// 描きたい。そこで行 = バー、列 = 全バーのセグメントkeyの和集合、に変換する。
// あるバーに存在しないkeyの値はundefinedになり、rechartsはその行では何も描かない。
// → 「借方バーにだけ売上原価がある」「3本目の債務超過バーにだけspacerがある」を自然に表現できる
type Row = { name: string; __segments: Record<string, Segment> } & Record<
  string,
  number
>;

export interface StackColumn {
  key: string;
  label: string;
  colorRole: string;
}

export function toStackRows(chart: StackChart): {
  rows: Row[];
  columns: StackColumn[];
} {
  const columns: StackColumn[] = [];
  const rows = chart.bars.map((bar) => {
    // __segments: この行のセグメントメタ（実値など）。ツールチップはここから引くため、
    // フロントは科目辞書を一切持たない。
    // Object.create(null): キーがAPI由来のため、メタの持ち場所は"__proto__"等でも
    // プロトタイプに干渉しない素のマップにする（row本体の列は値が数値だけなので干渉の実害がない）
    const row = {
      name: bar.label,
      __segments: Object.create(null) as Record<string, Segment>,
    } as Row;
    bar.segments.forEach((s) => {
      if (!columns.some((c) => c.key === s.key)) {
        columns.push({ key: s.key, label: s.label, colorRole: s.colorRole });
      }
      row[s.key] = s.amount; // 描画は常に正のamount
      // ratioは別フィールドに持たせてLabelListのdataKeyで参照する
      // （ratioがnull=非表示セグメントはフィールド自体を作らない → ラベルが描かれない）
      if (s.ratio != null) {
        row[`${s.key}Ratio`] = s.ratio;
      }
      row.__segments[s.key] = s;
    });
    return row;
  });
  // columnsの順序 = バー出現順*セグメント出現順。バックエンドが決めた積み上げ順が
  // そのまま描画順になる（APIの配列順序は契約の一部）
  return { rows, columns };
}

export interface StackedBarChartProps {
  chart: StackChart;
  width?: string | number;
  height?: string | number;
}

export function StackedBarChart({
  chart,
  width = '90%',
  height = 400,
}: StackedBarChartProps) {
  if (!chart.renderable) {
    // カルーセル内でチャートと差し替わるため、サイズを揃えてスライド切替時のレイアウト跳ねを防ぐ
    return <ChartUnavailable note={chart.note} width={width} height={height} />;
  }
  const { rows, columns } = toStackRows(chart);

  return (
    <ResponsiveContainer
      className="bar-container"
      width={width}
      height={height}
    >
      <BarChart data={rows}>
        {/* Y軸反転: 積み上げを「上から下」に描く（BSの「上=流動・下=純資産」の慣習を保つ）。
            domainのdataMaxで最も高いバーに全バーの縮尺を合わせる */}
        <YAxis reversed hide domain={[0, 'dataMax']} />
        <Tooltip
          cursor={false}
          wrapperStyle={{
            backgroundColor: tooltipBackgroundColor,
            textAlign: 'left',
          }}
          labelFormatter={() => ''} // 行インデックスが出てしまうため空に
          formatter={(_value: unknown, key: unknown, item: unknown) => {
            const payload = (item as { payload?: Row } | undefined)?.payload;
            const s: Segment | undefined = payload?.__segments?.[key as string];
            if (!s || hiddenRoles.has(s.colorRole)) {
              return [null, null];
            }
            // 表示はsignedAmount: 債務超過の純資産や損失は負で見せる
            return [formatAmount(s.signedAmount), s.label];
          }}
        />
        {columns.map(({ key, label, colorRole }) => (
          <Bar
            key={key}
            dataKey={key}
            stackId="a"
            fill={colorForRole(colorRole)}
            isAnimationActive={false}
          >
            <LabelList
              dataKey={`${key}Ratio`}
              fill={stackLabelColor}
              position="center"
              formatter={(value: number) => `${label}: ${value}%`}
            />
          </Bar>
        ))}
      </BarChart>
    </ResponsiveContainer>
  );
}
