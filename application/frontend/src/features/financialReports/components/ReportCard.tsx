import React from 'react';
import { Link } from '@mui/material';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import CardContent from '@mui/material/CardContent';
import AppCarousel from '@/components/appCarousel/AppCarousel';
import FirebaseAnalytics from '@/plugins/firebase/analytics';
import { StackedBarChart, WaterfallChart } from '@/shared/financialCharts';
import type { FinancialReport } from '../api/types';

// 会計基準は日本基準以外のみサブヘッダに表示する（判断材料として意味を持つのは
// 「日本基準とは表示形式が違う」ことを示す場合だけのため）。
// accountingStandardを描画分岐に使わないことがこの設計の規律
// （書き始めたらチャート契約で吸収できていないサイン）
const nonJgaapBadge: Record<string, string> = {
  ifrs: 'IFRS',
  us_gaap: '米国基準',
};

export function ReportCard({ report }: { report: FinancialReport }) {
  const consolidationTypeLabel =
    report.consolidationType === 'consolidated' ? '連結' : '単体';
  const standardLabel = nonJgaapBadge[report.accountingStandard];
  const subheaderSuffix = standardLabel
    ? `（${consolidationTypeLabel}・${standardLabel}）`
    : `（${consolidationTypeLabel}）`;

  return (
    <Card>
      <CardHeader
        title={
          <div className="financial-statement-card-header">
            <Link
              title={`${report.companyName}（株探）`}
              underline="none"
              target="_blank"
              href={`https://kabutan.jp/stock/?code=${report.stockCode}`}
            >
              <span
                onClick={() =>
                  FirebaseAnalytics.logClickEvent({
                    content_type: 'url',
                    link_domain: 'kabutan.jp',
                    link_url: `https://kabutan.jp/stock/?code=${report.stockCode}`,
                    custom_stock_code: report.stockCode ?? '',
                    custom_title: report.companyName ?? '',
                    custom_timespan: `${report.fiscalYearStartDate}-${report.fiscalYearEndDate}`,
                  })
                }
              >
                {report.companyName}
              </span>
            </Link>
          </div>
        }
        subheader={
          <div className="financial-statement-card-header">
            {`${report.stockCode} : ${report.fiscalYearStartDate} - ${report.fiscalYearEndDate}${subheaderSuffix}`}
          </div>
        }
      />
      <CardContent>
        <AppCarousel>
          <StackedBarChart chart={report.balanceSheet} />
          <StackedBarChart chart={report.profitLoss} />
          <WaterfallChart chart={report.cashFlow} />
        </AppCarousel>
      </CardContent>
    </Card>
  );
}
