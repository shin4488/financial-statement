import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ApolloProvider, useQuery } from '@apollo/client';
import { Grid } from '@mui/material';
import CircularProgress from '@mui/material/CircularProgress';
import InfiniteScroll from 'react-infinite-scroller';
import {
  cashFlowTypeRequestMap,
  financialStatementOffsetUnit,
} from '@/constants/values';
import { FINANCIAL_REPORTS_QUERY } from './api/financialReportsQuery';
import { financialReportsClient } from './apolloClient';
import { parseCashFlowType, parseStockCodes } from './searchCriteria';
import { ReportCard } from './components/ReportCard';
import { ReportListLayout } from './components/ReportListLayout';
import { trackEvent } from '@/plugins/firebase/analytics';
import { searchAnalytics } from './analytics';

// URLクエリ（例: /?stock-codes=7203,4502&cash-flow-type=healthy）→ GraphQL変数。
// 検索条件をReduxでなくURLに持つ理由: 検索結果画面をURLで共有・ブックマークできる
function useQueryVariables() {
  const [searchParams] = useSearchParams();
  return useMemo(() => {
    const codes = parseStockCodes(searchParams);
    const cfRequest = cashFlowTypeRequestMap[parseCashFlowType(searchParams)];
    return {
      limit: financialStatementOffsetUnit,
      offset: 0,
      stockCodes: codes.length > 0 ? codes : null,
      operatingCfSign: cfRequest.operatingActivitiesCashFlowSign,
      investingCfSign: cfRequest.investingActivitiesCashFlowSign,
      financingCfSign: cfRequest.financingActivitiesCashFlowSign,
    };
  }, [searchParams]);
}

function FinancialReportList() {
  const variables = useQueryVariables();
  const [searchParams] = useSearchParams();
  const { data, loading, error, fetchMore } = useQuery(
    FINANCIAL_REPORTS_QUERY,
    {
      variables,
      notifyOnNetworkStatusChange: true, // fetchMore中もloadingを反映させる
    },
  );
  const reports = data?.financialReports ?? [];
  // StrictMode、追加読込、再レンダーで最初の検索結果を重複計測しない。
  const resultTracked = useRef<{ key: string; complete: boolean }>();
  useEffect(() => {
    const key = JSON.stringify(variables);
    if (resultTracked.current?.key !== key) {
      resultTracked.current = { key, complete: false };
    }
    if (loading || resultTracked.current.complete || (!data && !error)) {
      return;
    }
    resultTracked.current.complete = true;
    trackEvent('report_result', {
      ...searchAnalytics(searchParams),
      result_status: error ? 'error' : reports.length ? 'success' : 'empty',
      result_count: error ? 0 : reports.length,
      unavailable_count: error
        ? 0
        : reports.filter((report) =>
            [report.balanceSheet, report.profitLoss, report.cashFlow].some(
              (chart) => !chart.renderable,
            ),
          ).length,
    });
  }, [data, error, loading, reports, searchParams, variables]);
  // 「件数がページサイズの倍数」だけで終端判定すると、総件数がちょうど倍数のとき
  // 空レスポンスを無限に取り続けるため、「ページサイズ未満のレスポンスを受けたら終端」を
  // 状態として持つ（件数フィールドをAPIに増やさず一覧APIをシンプルに保つ意図）
  const [reachedEnd, setReachedEnd] = useState(false);
  useEffect(() => setReachedEnd(false), [variables]); // 検索条件が変わったら判定をリセット
  const hasMore =
    !reachedEnd &&
    reports.length > 0 &&
    reports.length % financialStatementOffsetUnit === 0;

  return (
    <>
      <InfiniteScroll
        loadMore={() => {
          // 多重発火ガード（scroller側は連打してくる）
          if (loading || reachedEnd) {
            return;
          }
          // offsetだけ進める。結果の連結はApolloのtypePolicies（merge）が行う
          fetchMore({ variables: { ...variables, offset: reports.length } })
            .then((result) => {
              const fetched = result.data?.financialReports?.length ?? 0;
              trackEvent('report_load_more', {
                ...searchAnalytics(searchParams),
                result_status: fetched ? 'success' : 'empty',
                result_count: fetched,
              });
              if (fetched < financialStatementOffsetUnit) {
                setReachedEnd(true);
              }
            })
            .catch(() => {
              trackEvent('report_load_more', { result_status: 'error' });
            }); // 失敗時は終端扱いにせず、次のスクロールで再試行させる
        }}
        hasMore={hasMore}
        loader={<CircularProgress key="loader" style={{ marginBottom: 5 }} />}
      >
        <Grid container spacing={2} padding={1}>
          {reports.map((report) => (
            <Grid item xs={12} md={6} lg={4} key={report.id}>
              <ReportCard report={report} />
            </Grid>
          ))}
        </Grid>
      </InfiniteScroll>
      {/* reports.length === 0 の条件を付ける理由: fetchMore中（追加読込）は
          InfiniteScrollのloaderが表示されるため、全面スピナーは
          初回読込と検索条件切替（結果が空になる間）だけに限定する */}
      {loading && reports.length === 0 && (
        <CircularProgress style={{ marginTop: 20 }} />
      )}
      {!loading && error && (
        <p role="alert">
          財務データを取得できませんでした。時間をおいて再度お試しください。
        </p>
      )}
      {!loading && !error && reports.length === 0 && (
        <p>条件に一致する企業がありません。</p>
      )}
    </>
  );
}

// 専用のApolloクライアントをこのページ配下だけに提供する
// （共有シングルトンのキャッシュ設定に手を入れず、他ページと独立に保つため）
export default function FinancialReportListPage() {
  return (
    <ApolloProvider client={financialReportsClient}>
      <ReportListLayout>
        <div className="App">
          <FinancialReportList />
        </div>
      </ReportListLayout>
    </ApolloProvider>
  );
}
