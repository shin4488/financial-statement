import React from 'react';
import { Box, Stack, Typography } from '@mui/material';
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
import { colorByRole } from './colorRoles';
import type { FreeCashFlowTrend } from './types';

type Point = FreeCashFlowTrend['points'][number];
type Row = Point & { amountMillions: number | null; periodLabel: string };

const MILLION = 1_000_000;
const CHART_HEIGHT = 305;
const COMPACT_TOP_MARGIN = 75;
const CHART_BOTTOM = 275;
const exactNumber = new Intl.NumberFormat('ja-JP', {
  maximumFractionDigits: 6,
});

export function periodTickFontSize(
  labels: string[],
  chartWidth: number,
): number {
  if (chartWidth <= 0 || labels.length === 0) {
    return 16;
  }
  // 数字とスラッシュの文字幅を見込み、5つの年/月を省かずに並べられる最大サイズ。
  const widestLabelEm = Math.max(
    ...labels.map((label) =>
      [...label].reduce(
        (width, char) => width + (char === '/' ? 0.34 : 0.56),
        0,
      ),
    ),
  );
  const slotWidth = (chartWidth - 8) / labels.length;
  return Math.max(
    10,
    Math.min(16, Math.floor((slotWidth - 0.5) / widestLabelEm)),
  );
}

export function amountLabel(yen: number): string {
  return exactNumber.format(yen / MILLION);
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

type ValueLabelProps = {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  value?: number | null;
  index?: number;
  compact?: boolean;
  compactPositions?: { x: number; y: number }[];
};

function ValueLabel(props: ValueLabelProps) {
  const { x, y, width, height, value, index, compact, compactPositions } =
    props;
  if (x == null || y == null || width == null || value == null) {
    return null;
  }
  const labelY = value < 0 && height != null ? y + height - 7 : y - 7;
  const label = amountLabel(value);
  const compactPosition =
    compact && index != null ? compactPositions?.[index] : null;
  return (
    <text
      x={compactPosition?.x ?? x + width / 2}
      y={compactPosition?.y ?? labelY}
      textAnchor="middle"
      fontSize={16}
      fill={value < 0 ? colorByRole.cashDecrease : colorByRole.cashIncrease}
    >
      {label}
    </text>
  );
}

function estimateAmountWidth(label: string): number {
  return [...label].reduce(
    (width, char) => width + (char === ',' || char === '.' ? 5 : 9),
    0,
  );
}

export function compactAmountPositions(
  amounts: (number | null)[],
  domain: [number, number],
  chartWidth: number,
): { x: number; y: number }[] {
  if (chartWidth <= 0 || amounts.length === 0) {
    return [];
  }
  const slotWidth = (chartWidth - 8) / amounts.length;
  const plotHeight = CHART_BOTTOM - COMPACT_TOP_MARGIN;
  const span = domain[1] - domain[0];
  const zeroY = COMPACT_TOP_MARGIN + (domain[1] / span) * plotHeight;
  const placed: { x: number; y: number; width: number; height: number }[] = [];

  // 欠損年の「データなし」は基準線の上に固定されるため、その場所も空ける。
  amounts.forEach((amount, index) => {
    if (amount == null) {
      placed.push({
        x: 4 + (index + 0.5) * slotWidth,
        y: zeroY - 7,
        width: 51,
        height: 12,
      });
    }
  });

  return amounts.map((amount, index) => {
    if (amount == null) {
      return { x: 0, y: 0 };
    }
    const width = estimateAmountWidth(amountLabel(amount));
    const center = 4 + (index + 0.5) * slotWidth;
    const x = Math.min(
      chartWidth - width / 2 - 2,
      Math.max(width / 2 + 2, center),
    );
    const desiredY =
      zeroY - (amount > 0 ? (amount / MILLION / span) * plotHeight : 0) - 7;
    let y = Math.max(19, desiredY);
    while (
      y >= 19 &&
      placed.some(
        (other) =>
          Math.abs(x - other.x) < (width + other.width) / 2 + 2 &&
          Math.abs(y - other.y) < (19 + other.height) / 2 + 0.5,
      )
    ) {
      y -= 20;
    }
    y = Math.max(19, y);
    placed.push({ x, y, width, height: 19 });
    return { x, y };
  });
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
    <Box
      bgcolor="#fff"
      border="1px solid #ccc"
      p="10px"
      fontSize={14}
      textAlign="left"
    >
      <div>
        {point.fiscalYearStartDate} ～ {point.fiscalYearEndDate}
      </div>
      <div>営業CF：{exactAmount(point.operatingCf)}</div>
      <div>投資CF：{exactAmount(point.investingCf)}</div>
      <strong>フリーCF：{exactAmount(point.amount)}</strong>
    </Box>
  );
}

export function FreeCashFlowChart({ trend }: { trend: FreeCashFlowTrend }) {
  const [chartWidth, setChartWidth] = React.useState(0);
  const compactLabels = chartWidth > 0 && chartWidth < 470;
  const rows: Row[] = trend.points.map((point) => ({
    ...point,
    amountMillions: point.amount == null ? null : point.amount / MILLION,
    periodLabel: point.fiscalYearEndDate
      ? `${point.year}/${Number(point.fiscalYearEndDate.slice(5, 7))}`
      : String(point.year),
  }));
  const tickFontSize = periodTickFontSize(
    rows.map((point) => point.periodLabel),
    chartWidth,
  );
  const values = rows.flatMap((point) =>
    point.amountMillions == null ? [] : [point.amountMillions],
  );
  const maximum = Math.max(0, ...values);
  const minimum = Math.min(0, ...values);
  const domain: [number, number] =
    maximum === 0 && minimum === 0
      ? [0, 1]
      : [-paddedBound(-minimum), paddedBound(maximum)];
  const compactPositions = compactAmountPositions(
    rows.map((point) => point.amount ?? null),
    domain,
    chartWidth,
  );
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
      height={400}
      width="100%"
      textAlign="left"
      fontFamily="Roboto, Helvetica, Arial, sans-serif"
      color="rgba(0, 0, 0, 0.87)"
    >
      <Stack direction="row" alignItems="baseline" gap={1}>
        <Typography
          letterSpacing="inherit"
          fontFamily="inherit"
          component="h6"
          fontSize={16}
          fontWeight={400}
          lineHeight={1.4}
          color="#666"
        >
          フリーCF（過去5年）
        </Typography>
        {trend.renderable && (
          <Typography
            letterSpacing="inherit"
            fontFamily="inherit"
            component="span"
            fontSize={12}
            lineHeight={1.66}
            color="#666"
          >
            百万円
          </Typography>
        )}
      </Stack>
      {trend.renderable ? (
        <>
          <Box mt={1}>
            <ResponsiveContainer
              width="100%"
              height={CHART_HEIGHT}
              onResize={(width) => setChartWidth(width)}
            >
              <BarChart
                data={rows}
                margin={{
                  top: compactLabels ? COMPACT_TOP_MARGIN : 25,
                  right: 4,
                  bottom: 0,
                  left: 4,
                }}
              >
                <XAxis
                  dataKey="periodLabel"
                  interval={0}
                  tickLine={false}
                  tick={{ fontSize: tickFontSize }}
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
                  <LabelList
                    dataKey="amount"
                    content={
                      <ValueLabel
                        compact={compactLabels}
                        compactPositions={compactPositions}
                      />
                    }
                  />
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
          </Box>
          {trend.note && (
            <Typography
              letterSpacing="inherit"
              fontFamily="inherit"
              component="div"
              color="rgba(0, 0, 0, 0.6)"
              fontSize={12}
              lineHeight={1.2}
            >
              {trend.note}
            </Typography>
          )}
        </>
      ) : (
        <Stack height={335} alignItems="center" justifyContent="center">
          <Typography
            letterSpacing="inherit"
            fontFamily="inherit"
            component="span"
            color="rgba(0, 0, 0, 0.6)"
            fontSize={16}
            lineHeight={1.5}
          >
            {trend.note ?? '過去5年のデータがありません'}
          </Typography>
        </Stack>
      )}
    </Box>
  );
}
