import React, { useLayoutEffect, useRef, useState } from 'react';
import { Box } from '@mui/material';
import {
  Bar,
  BarChart,
  Label,
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

function FittingStackLabel(props: React.ComponentProps<typeof Label>) {
  const group = useRef<SVGGElement>(null);
  const [fits, setFits] = useState(false);

  useLayoutEffect(() => {
    const box = props.viewBox;
    if (
      !group.current ||
      !box ||
      !('width' in box) ||
      !('height' in box) ||
      typeof box.width !== 'number' ||
      typeof box.height !== 'number'
    ) {
      setFits(false);
      return;
    }
    // Rechartsの折り返し・フォントを維持し、実際の文字領域と区画の寸法を比べる。
    // hiddenでもSVGのgetBBoxは計測できる。上下左右に2pxずつ余裕を残す。
    const text = group.current.getBBox();
    setFits(
      text.width + 4 <= Math.abs(box.width) &&
        text.height + 4 <= Math.abs(box.height),
    );
  }, [props]);

  return (
    <g ref={group} visibility={fits ? 'visible' : 'hidden'} aria-hidden={!fits}>
      <Label {...props} content={undefined} />
    </g>
  );
}

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
    <Box width={width} height={height} m="auto">
      <ResponsiveContainer
        width="100%"
        height={typeof height === 'number' ? height : '100%'}
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
              fontSize: 14,
            }}
            // 標準のツールチップにしない理由: formatterで[null, null]を返しても
            // 空の行（約8px）が残るため、非表示role（spacer）を行ごと描かない
            content={(props: unknown) => {
              const p = props as {
                active?: boolean;
                payload?: {
                  dataKey?: unknown;
                  color?: string;
                  payload?: Row;
                }[];
              };
              const payload = p.payload ?? [];
              const row = payload[0]?.payload;
              if (!p.active || !row) {
                return null;
              }
              const entries = payload.filter((entry) => {
                const s = row.__segments[String(entry.dataKey)];
                return s !== undefined && !hiddenRoles.has(s.colorRole);
              });
              if (entries.length === 0) {
                return null;
              }
              // 見た目はrechartsの標準ツールチップに合わせる（白地・グレー枠・行間4px・系列色の文字）
              return (
                <Box
                  m={0}
                  p="10px"
                  bgcolor="#fff"
                  border="1px solid #ccc"
                  whiteSpace="nowrap"
                >
                  {entries.map((entry) => {
                    const s: Segment = row.__segments[String(entry.dataKey)];
                    return (
                      <Box key={s.key} color={entry.color} py="4px">
                        {/* 表示はsignedAmount: 債務超過の純資産や損失は負で見せる */}
                        {`${s.tooltipLabel ?? s.label} : ${formatAmount(
                          s.signedAmount,
                        )}`}
                        {s.ratio != null && ` (${s.ratio}%)`}
                      </Box>
                    );
                  })}
                </Box>
              );
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
                content={<FittingStackLabel />}
              />
            </Bar>
          ))}
        </BarChart>
      </ResponsiveContainer>
    </Box>
  );
}
