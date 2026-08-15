import React from 'react';
import { Link } from '@mui/material';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import CardContent from '@mui/material/CardContent';
import AppCarousel from './appCarousel/AppCarousel';
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
  // hasOwnPropertyで引く: 素の[]アクセスだとaccountingStandardが"constructor"等のとき
  // Object.prototypeのメンバーがラベルとして描画されるため
  const standardLabel = Object.prototype.hasOwnProperty.call(
    nonJgaapBadge,
    report.accountingStandard,
  )
    ? nonJgaapBadge[report.accountingStandard]
    : undefined;
  const kabutanUrl = `https://kabutan.jp/stock/?code=${encodeURIComponent(
    report.stockCode ?? '',
  )}`;
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
              // MUIのLinkはrelを自動付与しないため明示する。
              // noreferrer: 検索条件を含むURLが遷移先に渡るのを防ぐ
              rel="noopener noreferrer"
              href={kabutanUrl}
            >
              <span
                onClick={() =>
                  FirebaseAnalytics.logClickEvent({
                    content_type: 'url',
                    link_domain: 'kabutan.jp',
                    link_url: kabutanUrl,
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
