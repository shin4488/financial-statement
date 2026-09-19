import React from 'react';
import { Box, Chip, Stack, Tooltip, Typography } from '@mui/material';
import { amber, green, purple } from '@mui/material/colors';
import type { FinancialIndicatorsData, FinancialMetric } from './types';

type Metric = FinancialMetric;
const missing: Metric = { status: 'MISSING_DATA', value: null };
const emptyIndicators: FinancialIndicatorsData = {
  roe: missing,
  roa: missing,
  netProfitMargin: missing,
  assetTurnover: missing,
  financialLeverage: missing,
};

const percent = new Intl.NumberFormat('ja-JP', {
  style: 'percent',
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
});
const multiple = new Intl.NumberFormat('ja-JP', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

// 見出しと2行の列幅を共用する。罫線・外枠を作らず、MUIのBoxで必要な整列だけを指定する。
const columns =
  'clamp(36px, 10cqi, 46px) minmax(0, 1.1fr) 10px minmax(0, 1fr) 10px minmax(0, 1fr) 10px minmax(0, 1fr)';
const factors = [
  {
    key: 'netProfitMargin',
    category: '収益性',
    lines: ['売上高', '純利益率'],
    colors: amber,
    unit: undefined,
  },
  {
    key: 'assetTurnover',
    category: '効率性',
    lines: ['総資産', '回転率'],
    colors: green,
    unit: '回',
  },
  {
    key: 'financialLeverage',
    category: '健全性',
    lines: ['財務', 'レバレッジ'],
    colors: purple,
    unit: '倍',
  },
] as const;

function MetricValue({
  metric,
  label,
  unit,
  highlight = false,
  disclosed = false,
}: {
  metric: Metric;
  label: string;
  unit?: string;
  highlight?: boolean;
  disclosed?: boolean;
}) {
  if (
    metric.status !== 'AVAILABLE' ||
    metric.value == null ||
    !Number.isFinite(metric.value)
  ) {
    const text = metric.status === 'NOT_CALCULABLE' ? '算出不可' : 'データなし';
    return (
      <Typography
        aria-label={`${label}：${text}`}
        variant="caption"
        color="text.secondary"
        sx={{
          fontSize: 'clamp(11px, 3.3cqi, 13px)',
          letterSpacing: 0,
          pt: 0.5,
          overflowWrap: 'anywhere',
        }}
      >
        {text}
      </Typography>
    );
  }
  const value = percent.format(metric.value);
  // 銀行などの桁数が多い比率も、狭いカードで数値と%を一緒に読めるようにする。
  const numberScale = Math.min(1, 7 / value.length);
  return (
    <Stack spacing={0.5} sx={{ minWidth: 0 }} aria-label={`${label}：${value}`}>
      <Typography
        title={value}
        color={highlight ? 'primary.main' : 'text.primary'}
        sx={{
          fontSize: highlight
            ? `clamp(12px, ${5.6 * numberScale}cqi, ${28 * numberScale}px)`
            : `clamp(11px, ${4.9 * numberScale}cqi, ${25 * numberScale}px)`,
          fontWeight: highlight ? 800 : 600,
          lineHeight: 1.3,
          fontVariantNumeric: 'tabular-nums',
          overflowWrap: 'anywhere',
        }}
      >
        {value}
      </Typography>
      {disclosed && (
        <Tooltip title="有価証券報告書の企業公表値です。当サイトの期首・期末平均による計算値ではありません。計算条件は提出書類の注記によります。">
          <Typography
            component="span"
            tabIndex={0}
            variant="caption"
            color="text.secondary"
          >
            企業公表値
          </Typography>
        </Tooltip>
      )}
      {unit && (
        <Typography
          variant="caption"
          color="text.secondary"
          title={`${multiple.format(metric.value)}${unit}`}
          sx={{ fontSize: 'clamp(11px, 3cqi, 13px)', overflowWrap: 'anywhere' }}
        >
          {multiple.format(metric.value)}
          {unit}
        </Typography>
      )}
    </Stack>
  );
}

function Operator({ children }: { children: React.ReactNode }) {
  return (
    <Typography
      aria-hidden="true"
      color="text.secondary"
      sx={{ fontSize: 16, pt: 0.5 }}
    >
      {children}
    </Typography>
  );
}

export function FinancialIndicators({
  indicators,
  compact = false,
}: {
  indicators?: FinancialIndicatorsData | null;
  compact?: boolean;
}) {
  // 拡張の永続化済みキャッシュには追加前のレスポンスが残ることがある。
  const values = indicators ?? emptyIndicators;
  return (
    <Stack
      component="section"
      aria-label="ROE・ROA"
      spacing={5}
      sx={{
        height: compact ? 300 : 400,
        justifyContent: compact ? 'flex-start' : 'center',
        pt: compact ? 1 : 0,
        textAlign: 'center',
        containerType: 'inline-size',
      }}
    >
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: columns,
          alignItems: 'start',
        }}
      >
        <Box sx={{ gridColumn: 'span 3' }} />
        {factors.map((factor, index) => (
          <React.Fragment key={factor.key}>
            {index > 0 && <Box />}
            <Stack spacing={1} alignItems="center">
              <Chip
                label={factor.category}
                size="small"
                sx={{
                  height: 28,
                  fontSize: 'clamp(12px, 3.8cqi, 16px)',
                  fontWeight: 600,
                  borderRadius: 1,
                  bgcolor: factor.colors[50],
                  color: factor.colors[800],
                  '& .MuiChip-label': { px: 0.75 },
                }}
              />
              <Stack>
                {factor.lines.map((line) => (
                  <Typography
                    key={line}
                    variant="caption"
                    color="text.secondary"
                    sx={{
                      fontSize: 'clamp(10px, 3.6cqi, 16px)',
                      fontWeight: 500,
                      lineHeight: 1.5,
                      letterSpacing: 0,
                    }}
                  >
                    {line}
                  </Typography>
                ))}
              </Stack>
            </Stack>
          </React.Fragment>
        ))}
      </Box>
      {(['roe', 'roa'] as const).map((key) => (
        <Box
          key={key}
          role="group"
          aria-label={key.toUpperCase()}
          sx={{
            display: 'grid',
            gridTemplateColumns: columns,
            minHeight: 64,
            alignItems: 'start',
          }}
        >
          <Typography
            sx={{
              fontSize: 'clamp(16px, 4.5cqi, 20px)',
              fontWeight: 800,
              textAlign: 'left',
              pt: 0.25,
            }}
          >
            {key.toUpperCase()}
          </Typography>
          <MetricValue
            metric={values[key]}
            label={key.toUpperCase()}
            highlight
            disclosed={key === 'roe' && values.roe.source === 'DISCLOSED'}
          />
          <Operator>=</Operator>
          {factors.map((factor, index) => (
            <React.Fragment key={factor.key}>
              {index > 0 && (
                <Operator>
                  {key === 'roa' && factor.key === 'financialLeverage'
                    ? ''
                    : '×'}
                </Operator>
              )}
              {key === 'roa' && factor.key === 'financialLeverage' ? (
                <Typography
                  aria-label="財務レバレッジ：対象外"
                  color="text.secondary"
                >
                  —
                </Typography>
              ) : (
                <MetricValue
                  metric={values[factor.key]}
                  label={factor.lines.join('')}
                  unit={factor.unit}
                />
              )}
            </React.Fragment>
          ))}
        </Box>
      ))}
    </Stack>
  );
}
