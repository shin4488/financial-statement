import React from 'react';
import { Box, Chip, Stack, Typography } from '@mui/material';
import { amber, green, purple } from '@mui/material/colors';
import type { FinancialReport } from '../api/types';

type Indicators = FinancialReport['financialIndicators'];
type Metric = Indicators['roe'];

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
  '32px minmax(0, 1fr) 12px minmax(0, 1fr) 12px minmax(0, 1fr) 12px minmax(0, 1fr)';
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
}: {
  metric: Metric;
  label: string;
  unit?: string;
  highlight?: boolean;
}) {
  if (metric.status !== 'AVAILABLE' || metric.value == null) {
    const text = metric.status === 'NOT_CALCULABLE' ? '算出不可' : 'データなし';
    return (
      <Typography
        aria-label={`${label}：${text}`}
        variant="caption"
        color="text.secondary"
        sx={{
          fontSize: 'clamp(10px, 3cqi, 11px)',
          letterSpacing: 0,
          pt: 0.5,
          whiteSpace: 'nowrap',
        }}
      >
        {text}
      </Typography>
    );
  }
  const value = percent.format(metric.value);
  return (
    <Stack spacing={0.5} sx={{ minWidth: 0 }} aria-label={`${label}：${value}`}>
      <Typography
        title={value}
        color={highlight ? 'primary.main' : 'text.primary'}
        sx={{
          fontSize: 'clamp(11px, 4cqi, 20px)',
          fontWeight: highlight ? 600 : 400,
          fontVariantNumeric: 'tabular-nums',
          overflowWrap: 'anywhere',
        }}
      >
        {value}
      </Typography>
      {unit && (
        <Typography
          variant="caption"
          color="text.secondary"
          title={`${multiple.format(metric.value)}${unit}`}
          sx={{ fontSize: 10, overflowWrap: 'anywhere' }}
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
      sx={{ fontSize: 14, pt: 0.25 }}
    >
      {children}
    </Typography>
  );
}

export function FinancialIndicators({
  indicators,
}: {
  indicators: Indicators;
}) {
  return (
    <Stack
      component="section"
      aria-label="ROE・ROA"
      spacing={4}
      sx={{
        height: 400,
        justifyContent: 'center',
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
                  height: 22,
                  fontSize: 11,
                  borderRadius: 1,
                  bgcolor: factor.colors[50],
                  color: factor.colors[800],
                  '& .MuiChip-label': { px: 0.75 },
                }}
              />
              <Typography
                variant="caption"
                color="text.secondary"
                sx={{
                  fontSize: 'clamp(10px, 3cqi, 12px)',
                  lineHeight: 1.6,
                  whiteSpace: 'nowrap',
                }}
              >
                {factor.lines[0]}
                <br />
                {factor.lines[1]}
              </Typography>
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
            minHeight: 48,
            alignItems: 'start',
          }}
        >
          <Typography
            sx={{ fontSize: 13, fontWeight: 600, textAlign: 'left', pt: 0.25 }}
          >
            {key.toUpperCase()}
          </Typography>
          <MetricValue
            metric={indicators[key]}
            label={key.toUpperCase()}
            highlight
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
                  metric={indicators[factor.key]}
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
