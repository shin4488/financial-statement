import React from 'react';
import { Box, Typography } from '@mui/material';
import {
  Bar,
  BarChart,
  Cell,
  LabelList,
  ReferenceDot,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { colorByRole } from '@/shared/financialCharts';
import type { FinancialReport } from '../api/types';

type Trend = FinancialReport['freeCashFlowTrend'];
type Point = Trend['points'][number];
type Row = Point & { amountMillions: number | null; periodLabel: string };

const MILLION = 1_000_000;
const exactNumber = new Intl.NumberFormat('ja-JP', {
  maximumFractionDigits: 6,
});

export function amountLabel(yen: number): string {
  return `${yen > 0 ? '+' : ''}${exactNumber.format(yen / MILLION)}`;
}

function exactAmount(yen: number): string {
  return `${amountLabel(yen)}百万円`;
}

function paddedBound(value: number): number {
  if (value === 0) {
    return 0;
  }
  const step = 10 ** Math.floor(Math.log10(value)) / 2;
  return Math.ceil((value * 1.15) / step) * step;
}

function ValueLabel(props: unknown) {
  const { x, y, width, height, value } = props as {
    x?: number;
    y?: number;
    width?: number;
    height?: number;
    value?: number | null;
  };
  if (x == null || y == null || width == null || value == null) {
    return null;
  }
  return (
    <text
      x={x + width / 2}
      y={value < 0 && height != null ? y + height - 7 : y - 7}
      textAnchor="middle"
      fontSize={11}
      fill="#333"
    >
      {amountLabel(value)}
    </text>
  );
}

function PointTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: { payload: Row }[];
}) {
  const point = payload?.[0]?.payload;
  if (
    !active ||
    !point ||
    point.amount == null ||
    point.operatingCf == null ||
    point.investingCf == null
  ) {
    return null;
  }
  return (
    <div
      style={{
        background: '#fff',
        border: '1px solid #ccc',
        padding: 10,
        textAlign: 'left',
      }}
    >
      <div>
        {point.fiscalYearStartDate} ～ {point.fiscalYearEndDate}
      </div>
      <div>営業CF：{exactAmount(point.operatingCf)}</div>
      <div>投資CF：{exactAmount(point.investingCf)}</div>
      <strong>フリーキャッシュフロー：{exactAmount(point.amount)}</strong>
    </div>
  );
}

export function FreeCashFlowChart({ trend }: { trend: Trend }) {
  const rows: Row[] = trend.points.map((point) => ({
    ...point,
    amountMillions: point.amount == null ? null : point.amount / MILLION,
    periodLabel: point.fiscalYearEndDate
      ? `${point.year}/${Number(point.fiscalYearEndDate.slice(5, 7))}`
      : String(point.year),
  }));
  const values = rows.flatMap((point) =>
    point.amountMillions == null ? [] : [point.amountMillions],
  );
  const maximum = Math.max(0, ...values);
  const minimum = Math.min(0, ...values);
  const domain: [number, number] =
    maximum === 0 && minimum === 0
      ? [0, 1]
      : [-paddedBound(-minimum), paddedBound(maximum)];
  const accessibleSummary = rows
    .map(
      (point) =>
        `${point.year}年：${
          point.amount == null ? 'データなし' : exactAmount(point.amount)
        }`,
    )
    .join('、');

  return (
    <Box
      component="section"
      aria-label={`フリーキャッシュフローの過去5年の推移。${accessibleSummary}`}
      sx={{ height: 400, width: '100%', textAlign: 'left' }}
    >
      <Typography variant="subtitle1" sx={{ fontWeight: 700, lineHeight: 1.4 }}>
        フリーキャッシュフロー
      </Typography>
      <Typography variant="caption" color="text.secondary">
        過去5年の推移
      </Typography>
      {trend.renderable ? (
        <>
          <Typography variant="caption" component="div" sx={{ mt: 1 }}>
            百万円
          </Typography>
          <ResponsiveContainer width="100%" height={305}>
            <BarChart
              data={rows}
              margin={{ top: 25, right: 4, bottom: 0, left: 4 }}
            >
              <XAxis
                dataKey="periodLabel"
                tickLine={false}
                tick={{ fontSize: 10 }}
              />
              <YAxis hide width={0} domain={domain} />
              <ReferenceLine y={0} stroke="#8f9bad" />
              {rows
                .filter((point) => point.amount == null)
                .map((point) => (
                  <ReferenceDot
                    key={point.year}
                    x={point.periodLabel}
                    y={0}
                    r={0}
                    label={{
                      value: 'データなし',
                      position: 'top',
                      fill: '#687587',
                      fontSize: 10,
                    }}
                  />
                ))}
              <Tooltip cursor={false} content={<PointTooltip />} />
              <Bar
                dataKey="amountMillions"
                barSize={32}
                minPointSize={3}
                isAnimationActive={false}
              >
                <LabelList dataKey="amount" content={<ValueLabel />} />
                {rows.map((point) => (
                  <Cell
                    key={point.year}
                    fill={
                      point.amount == null
                        ? 'transparent'
                        : point.amount < 0
                        ? colorByRole.cashDecrease
                        : colorByRole.cashIncrease
                    }
                  />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
          <Typography
            variant="caption"
            color="text.secondary"
            component="div"
            sx={{ lineHeight: 1.2 }}
          >
            {trend.note ?? 'フリーキャッシュフロー＝営業CF＋投資CF'}
          </Typography>
        </>
      ) : (
        <Box
          sx={{
            height: 335,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Typography color="text.secondary">
            {trend.note ?? '過去5年のデータがありません'}
          </Typography>
        </Box>
      )}
    </Box>
  );
}
