import React from 'react';
import { Box, Stack, Typography } from '@mui/material';
import {
  Bar,
  BarChart,
  Cell,
  LabelList,
  Text,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { ChartUnavailable } from './ChartUnavailable';
import { colorForRole, tooltipBackgroundColor } from './colorRoles';
import { formatAmountInMillions } from './formatAmount';
import type {
  WaterfallChart as WaterfallChartData,
  WaterfallStep,
} from './types';

const chartSideMargin = 5;
const chartBottomMargin = 5;
// 金額ラベルを置くため、グラフの上端に最低限空ける余白
const chartTopMargin = 28;
const xAxisHeight = 30;
// rechartsのラベル（position="top"）と同じく、バーの上端からこの距離の位置に金額の文字の下端を置く
const valueLabelOffset = 5;

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

export function stepTickFontSize(labels: string[], chartWidth: number): number {
  if (chartWidth <= 0 || labels.length === 0) {
    return 16;
  }
  // rechartsは既定で重なる目盛りを間引き、狭い幅では区分名が欠ける。
  // 全区分を並べられるよう、左右の余白を除いた1区分の幅にラベル間の隙間を残して収まる最大サイズにする。
  // 全角は1文字1em、半角は英大文字（CF）の幅を見込む
  const widestLabelEm = Math.max(
    ...labels.map((label) =>
      [...label].reduce(
        (width, char) => width + (char.charCodeAt(0) > 0xff ? 1 : 0.72),
        0,
      ),
    ),
  );
  const slotWidth = (chartWidth - chartSideMargin * 2) / labels.length;
  return Math.max(
    10,
    Math.min(16, Math.floor((slotWidth - 4) / widestLabelEm)),
  );
}

// 金額ラベルの位置を計算できるよう、縦の表示範囲を自前で決める。累積が負になるケースでは0より下も含める。
// rechartsに表示範囲を任せたときと同じ範囲になるよう、0を含む5本の目盛りが切りのよい値になるまで広げる
export function waterfallDomain(rows: Row[]): [number, number] {
  const low = Math.min(0, ...rows.map((row) => row.base));
  const high = Math.max(0, ...rows.map((row) => row.base + row.span));
  if (high <= low) {
    return [low, low + 1];
  }
  const tickCount = 5;
  // 浮動小数点の誤差で1つ上へ切り上げないよう、わずかに引いてから切り上げる
  const ceil = (value: number) => Math.ceil(value - 1e-9);
  for (let correction = 0; ; correction++) {
    const roughStep = (high - low) / (tickCount - 1);
    const digitValue = 10 ** (Math.floor(Math.log10(roughStep)) + 1);
    const ratioScale = digitValue === 10 ? 0.1 : 0.05;
    // rechartsは10進数で計算するため、浮動小数点の誤差を丸めて切りのよい値にそろえる
    const step = Number(
      (
        (ceil(roughStep / digitValue / ratioScale) + correction) *
        ratioScale *
        digitValue
      ).toPrecision(12),
    );
    const below = ceil(-low / step);
    const above = ceil(high / step);
    if (below + above + 1 <= tickCount) {
      // -0 を 0 にそろえる
      return high > 0
        ? [-below * step + 0, (tickCount - 1 - below) * step]
        : [-(tickCount - 1 - above) * step + 0, above * step];
    }
  }
}

// 金額の文字幅（em）。数字と符号は約0.56em、カンマと小数点は約0.31em
function amountWidthEm(label: string): number {
  return [...label].reduce(
    (width, char) => width + (char === ',' || char === '.' ? 0.3125 : 0.5625),
    0,
  );
}

type ValueLabelLayout = {
  fontSize: number;
  // 各金額ラベルの中央のx座標と、文字の下端のy座標
  positions: { x: number; y: number }[];
};

// バー上の金額ラベルの文字サイズと位置を決める。
// 文字は1区分の幅に収まるまで小さくし、読めなくならないよう10pxで止める。
// それでも隣のラベルと重なるもの（10pxのときだけ起きる）は、重ならない位置まで上へずらす。
// 10pxの文字を1行ずらしても、上端の余白に収まる
export function layoutValueLabels(
  rows: Row[],
  domain: [number, number],
  chartWidth: number,
  chartHeight: number,
): ValueLabelLayout {
  if (chartWidth <= 0 || rows.length === 0) {
    return { fontSize: 16, positions: [] };
  }
  const labels = rows.map((row) => formatAmountInMillions(row.value));
  const slotWidth = (chartWidth - chartSideMargin * 2) / rows.length;
  const fontSize = Math.max(
    10,
    Math.min(
      16,
      Math.floor((slotWidth - 4) / Math.max(...labels.map(amountWidthEm))),
    ),
  );
  const lineHeight = fontSize + 2;
  const [low, high] = domain;
  const plotHeight =
    chartHeight - chartBottomMargin - xAxisHeight - chartTopMargin;
  const placed: { x: number; y: number; width: number }[] = [];
  const positions = rows.map((row, index) => {
    const width = amountWidthEm(labels[index]) * fontSize;
    // グラフの左右の端からはみ出さないよう、端のラベルは内側へ寄せる
    const x = Math.min(
      chartWidth - width / 2 - 1,
      Math.max(width / 2 + 1, chartSideMargin + slotWidth * (index + 0.5)),
    );
    let y =
      chartTopMargin +
      ((high - (row.base + row.span)) / (high - low)) * plotHeight -
      valueLabelOffset;
    const findOverlapped = () =>
      placed.find(
        (other) =>
          Math.abs(x - other.x) < (width + other.width) / 2 + 2 &&
          Math.abs(y - other.y) < lineHeight,
      );
    // 重なったラベルのすぐ上へ移し、移した先でも重なればさらに上へ移す
    for (
      let overlapped = findOverlapped();
      overlapped;
      overlapped = findOverlapped()
    ) {
      y = overlapped.y - lineHeight;
    }
    placed.push({ x, y, width });
    return { x, y };
  });
  return { fontSize, positions };
}

function ValueLabel({
  index,
  value,
  fill,
  layout,
}: {
  index?: number;
  value?: number;
  fill?: string;
  layout: ValueLabelLayout;
}) {
  const position = index == null ? undefined : layout.positions[index];
  if (!position || value == null) {
    return null;
  }
  // 単位はグラフ外に表示し、バー上には百万円単位の数値だけを出す
  return (
    <Text
      x={position.x}
      y={position.y}
      textAnchor="middle"
      verticalAnchor="end"
      fontSize={layout.fontSize}
      fill={fill}
      className="recharts-label"
    >
      {formatAmountInMillions(value)}
    </Text>
  );
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
  const chartElement = React.useRef<HTMLDivElement>(null);
  const [chartSize, setChartSize] = React.useState({ width: 0, height: 0 });

  React.useLayoutEffect(() => {
    const element = chartElement.current;
    if (!chart.renderable || !element) {
      return;
    }
    const updateSize = () => {
      const nextWidth = element.clientWidth;
      const nextHeight = element.clientHeight;
      setChartSize((current) =>
        current.width === nextWidth && current.height === nextHeight
          ? current
          : { width: nextWidth, height: nextHeight },
      );
    };
    const observer = new ResizeObserver(updateSize);
    observer.observe(element);
    updateSize();
    return () => observer.disconnect();
  }, [chart.renderable]);

  if (!chart.renderable) {
    // カルーセル内でチャートと差し替わるため、サイズを揃えてスライド切替時のレイアウト跳ねを防ぐ
    return <ChartUnavailable note={chart.note} width={width} height={height} />;
  }
  const rows = toWaterfallRows(chart.steps);
  const domain = waterfallDomain(rows);
  const labelLayout = layoutValueLabels(
    rows,
    domain,
    chartSize.width,
    chartSize.height,
  );

  return (
    <Stack width={width} height={height} m="auto">
      <Typography
        letterSpacing="inherit"
        fontFamily="inherit"
        component="div"
        fontSize={12}
        lineHeight="20px"
        textAlign="left"
      >
        百万円
      </Typography>
      <Box ref={chartElement} flex={1} minHeight={0}>
        {/* 非表示のカルーセル項目は0×0になるため、実寸があるときだけ描画する */}
        {chartSize.width > 0 && chartSize.height > 0 && (
          <BarChart
            data={rows}
            width={chartSize.width}
            height={chartSize.height}
            margin={{
              top: chartTopMargin,
              right: chartSideMargin,
              bottom: chartBottomMargin,
              left: chartSideMargin,
            }}
          >
            <XAxis
              dataKey="name"
              height={xAxisHeight}
              interval={0}
              tick={{
                fontSize: stepTickFontSize(
                  rows.map((row) => row.name),
                  chartSize.width,
                ),
              }}
            />
            <YAxis hide domain={domain} />
            <Tooltip
              cursor={false}
              wrapperStyle={{
                backgroundColor: tooltipBackgroundColor,
                opacity: '0.8',
                padding: '10px',
                fontSize: 14,
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
                const row = p.payload.find(
                  (e) => e.dataKey === 'span',
                )?.payload;
                if (!row) {
                  return null;
                }
                return (
                  <div>{`${p.label}: ${formatAmountInMillions(
                    row.value,
                  )}百万円`}</div>
                );
              }}
            />
            <Bar
              dataKey="base"
              stackId="w"
              fill="transparent"
              isAnimationActive={false}
            />
            <Bar dataKey="span" stackId="w" isAnimationActive={false}>
              <LabelList
                dataKey="value"
                content={<ValueLabel layout={labelLayout} />}
              />
              {rows.map((row) => (
                <Cell
                  key={row.step.key}
                  // colorRoleが無いのは古いAPI・クエリ（コピー先の拡張やサンプルデータ）から来た場合。
                  // その間も同じ見た目になるよう符号から同じroleを補う
                  fill={colorForRole(
                    row.step.colorRole ??
                      (row.value < 0 ? 'cashDecrease' : 'cashIncrease'),
                  )}
                />
              ))}
            </Bar>
          </BarChart>
        )}
      </Box>
    </Stack>
  );
}
