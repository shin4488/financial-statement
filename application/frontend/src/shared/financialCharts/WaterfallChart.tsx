import React from 'react';
import {
  Bar,
  BarChart,
  Cell,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { ChartUnavailable } from './ChartUnavailable';
import {
  cashDecreaseColor,
  cashIncreaseColor,
  tooltipBackgroundColor,
} from './colorRoles';
import { formatAmount } from './formatAmount';
import type {
  WaterfallChart as WaterfallChartData,
  WaterfallStep,
} from './types';

type Row = {
  name: string;
  base: number; // 浮かせるための透明部分の高さ
  span: number; // 色付き部分の高さ（絶対値）
  value: number; // 実値（符号付き。ラベル・ツールチップ用）
  step: WaterfallStep;
};

// ウォーターフォールは「透明のベース + 実バー」の2段積みで浮かせて描く。
// kind=balance（期首・期末残高）: 0起点で独立に描く。累積位置で描かない意図は、
//   CF計算書には為替換算差額があり「期首+3区分の合計 != 期末」になり得るため。
//   期末を実際の残高で0から描けばこの差異は自然に吸収される。
// kind=flow（3区分）: 直前までの累積位置から増減分だけ浮かせる。負の増減は下向き
export function toWaterfallRows(steps: WaterfallStep[]): Row[] {
  let cumulative = 0;
  return steps.map((step) => {
    if (step.kind === 'balance') {
      cumulative = step.amount; // 残高で累積をリセット（期首から始まる契約）
      return {
        name: step.label,
        base: 0,
        span: step.amount,
        value: step.amount,
        step,
      };
    }
    const start = cumulative;
    cumulative += step.amount;
    // 累積が負に落ちるケース（銀行の巨額な営業CFマイナス等）もmin/absで正しく描ける
    return {
      name: step.label,
      base: Math.min(start, cumulative),
      span: Math.abs(step.amount),
      value: step.amount,
      step,
    };
  });
}

export interface WaterfallChartProps {
  chart: WaterfallChartData;
  width?: string | number;
  height?: string | number;
}

export function WaterfallChart({
  chart,
  width = '90%',
  height = 400,
}: WaterfallChartProps) {
  if (!chart.renderable) {
    // カルーセル内でチャートと差し替わるため、サイズを揃えてスライド切替時のレイアウト跳ねを防ぐ
    return <ChartUnavailable note={chart.note} width={width} height={height} />;
  }
  const rows = toWaterfallRows(chart.steps);

  return (
    <ResponsiveContainer
      className="bar-container"
      width={width}
      height={height}
    >
      <BarChart data={rows}>
        <XAxis dataKey="name" />
        {/* domain自動: 累積が負になるケースで0より下も描画させる */}
        <YAxis hide domain={['auto', 'auto']} />
        <Tooltip
          cursor={false}
          wrapperStyle={{
            backgroundColor: tooltipBackgroundColor,
            opacity: '0.8',
            padding: '10px',
          }}
          content={(props: unknown) => {
            const p = props as {
              active?: boolean;
              label?: string;
              payload?: { dataKey?: string; payload?: Row }[];
            };
            if (!p.active || !p.payload) {
              return null;
            }
            // 色付き部分（span）のペイロードを選ぶ。配列の並びはBarの宣言順に依存するため、
            // 位置でなくdataKeyで引く
            const row = p.payload.find((e) => e.dataKey === 'span')?.payload;
            if (!row) {
              return null;
            }
            return <div>{`${p.label}: ${formatAmount(row.value)}`}</div>;
          }}
        />
        <Bar
          dataKey="base"
          stackId="w"
          fill="transparent"
          isAnimationActive={false}
        />
        <Bar dataKey="span" stackId="w" isAnimationActive={false}>
          {/* バー上のラベルもツールチップと同じformatAmount表記で出す。円のままだと桁が多く重なって読めない */}
          <LabelList
            dataKey="value"
            position="top"
            formatter={(value: number) => formatAmount(value)}
          />
          {rows.map((row) => (
            <Cell
              key={row.step.key}
              fill={row.value < 0 ? cashDecreaseColor : cashIncreaseColor}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
