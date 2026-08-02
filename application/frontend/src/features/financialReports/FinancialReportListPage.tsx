import React, { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ApolloProvider, useQuery } from '@apollo/client';
import { Grid } from '@mui/material';
import CircularProgress from '@mui/material/CircularProgress';
import InfiniteScroll from 'react-infinite-scroller';
import {
  CashFlowTypeValue,
  cashFlowTypeRequestMap,
  financialStatementOffsetUnit,
} from '@/constants/values';
import { CashFlowSign } from '@/__generated__/graphql';
import { FINANCIAL_REPORTS_QUERY } from './api/financialReportsQuery';
import { financialReportsClient } from './apolloClient';
import { ReportCard } from './components/ReportCard';
import { ReportListLayout } from './components/ReportListLayout';

// cashFlowTypeRequestMapの'POSITIVE'/'NEGATIVE'文字列 → 生成enum CashFlowSign への変換
const toCashFlowSign = (sign: 'POSITIVE' | 'NEGATIVE' | null) =>
  sign === 'POSITIVE'
    ? CashFlowSign.Positive
    : sign === 'NEGATIVE'
    ? CashFlowSign.Negative
    : null;

// URLクエリ（例: /v2?stock-codes=7203,4502&cash-flow-type=healthy）→ GraphQL変数。
// 検索条件をReduxでなくURLに持つ理由: 検索結果画面をURLで共有・ブックマークできる
function useQueryVariables() {
  const [searchParams] = useSearchParams();
  return useMemo(() => {
    const codes =
      searchParams.get('stock-codes')?.split(',').filter(Boolean) ?? null;
    const cfType = (searchParams.get('cash-flow-type') ??
      'none') as CashFlowTypeValue;
    const cfRequest =
      cashFlowTypeRequestMap[cfType] ?? cashFlowTypeRequestMap.none;
    return {
      limit: financialStatementOffsetUnit,
      offset: 0,
      stockCodes: codes,
      operatingCfSign: toCashFlowSign(cfRequest.operatingActivitiesCashFlowSign),
      investingCfSign: toCashFlowSign(cfRequest.investingActivitiesCashFlowSign),
      financingCfSign: toCashFlowSign(cfRequest.financingActivitiesCashFlowSign),
    };
  }, [searchParams]);
}

function FinancialReportList() {
  const variables = useQueryVariables();
  const { data, loading, fetchMore } = useQuery(FINANCIAL_REPORTS_QUERY, {
    variables,
    notifyOnNetworkStatusChange: true, // fetchMore中もloadingを反映させる
  });
  const reports = data?.financialReports ?? [];
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
              if (fetched < financialStatementOffsetUnit) {
                setReachedEnd(true);
              }
            })
            .catch(() => undefined); // 失敗時は終端扱いにせず、次のスクロールで再試行させる
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
      {!loading && reports.length === 0 && (
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
