import React, {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
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

// InfiniteScrollが追加読込を始める、一覧の下端と画面の下端の距離（px）
const loadMoreThreshold = 250;

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
  const resultTracked = useRef<{ key: string; complete: boolean }>(undefined);
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
  // 追加読込の要求中・失敗は、Apolloのloadingとは別に持つ。
  // Apolloのloadingは追加読込の応答を受けると下の.then/.catchより先にfalseに戻って再描画されるため、loadingだけを見ると同じoffsetを続けて要求する。
  const [loadMoreStatus, setLoadMoreStatus] = useState<
    'idle' | 'loading' | 'failed'
  >('idle');
  // 検索条件を切り替える前に送った追加読込の結果で、切り替えた後の状態を変えないために比べる
  const currentVariables = useRef(variables);
  useEffect(() => {
    currentVariables.current = variables;
    setReachedEnd(false);
    setLoadMoreStatus('idle');
  }, [variables]);
  const hasMore =
    !reachedEnd &&
    reports.length > 0 &&
    reports.length % financialStatementOffsetUnit === 0;
  const loadMoreFailed = loadMoreStatus === 'failed';
  const listRef = useRef<HTMLDivElement>(null);
  // 失敗時は終端扱いにせず、利用者が次に最下部までスクロールしたときに再試行させる。
  // 最下部に留まる間は、失敗の表示で高さが変わるたびや慣性スクロールでもscrollイベントが続くため、一覧の下端が画面の下端よりloadMoreThreshold以上下にあるときに追加読込を再開する。
  // 失敗した時点ですでに離れている場合と、失敗の表示の直後に離れる場合も取りこぼさないよう、失敗を表示する描画の中（useLayoutEffect）で位置を確かめてからscrollを待つ。
  useLayoutEffect(() => {
    if (!loadMoreFailed) {
      return;
    }
    const resumeAwayFromBottom = () => {
      const listBottom = listRef.current?.getBoundingClientRect().bottom ?? 0;
      if (listBottom - window.innerHeight >= loadMoreThreshold) {
        setLoadMoreStatus('idle');
      }
    };
    resumeAwayFromBottom();
    window.addEventListener('scroll', resumeAwayFromBottom, { passive: true });
    return () => window.removeEventListener('scroll', resumeAwayFromBottom);
  }, [loadMoreFailed]);

  return (
    <>
      <InfiniteScroll
        loadMore={() => {
          // 多重発火ガード（scroller側は連打してくる）。失敗中は上の再開を待つ
          if (loading || reachedEnd || loadMoreStatus !== 'idle') {
            return;
          }
          setLoadMoreStatus('loading');
          // offsetだけ進める。結果の連結はApolloのtypePolicies（merge）が行う
          fetchMore({ variables: { ...variables, offset: reports.length } })
            .then((result) => {
              const fetched = result.data?.financialReports?.length ?? 0;
              trackEvent('report_load_more', {
                ...searchAnalytics(searchParams),
                result_status: fetched ? 'success' : 'empty',
                result_count: fetched,
              });
              if (currentVariables.current !== variables) {
                return;
              }
              if (fetched < financialStatementOffsetUnit) {
                setReachedEnd(true);
              }
              setLoadMoreStatus('idle');
            })
            .catch(() => {
              trackEvent('report_load_more', { result_status: 'error' });
              if (currentVariables.current === variables) {
                setLoadMoreStatus('failed');
              }
            });
        }}
        // 失敗中はloaderを出さず、InfiniteScrollが再描画のたびに位置を判定してloadMoreを呼ぶのも止める（最下部では失敗した要求をすぐに送り直すため）
        hasMore={hasMore && !loadMoreFailed}
        threshold={loadMoreThreshold}
        loader={<CircularProgress key="loader" sx={{ mb: '5px' }} />}
      >
        <Grid container spacing={2} padding={1} ref={listRef}>
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
      {loading && reports.length === 0 && <CircularProgress sx={{ mt: 2.5 }} />}
      {!loading && (error || loadMoreFailed) && (
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

export default function FinancialReportListPage() {
  return (
    <ApolloProvider client={financialReportsClient}>
      <ReportListLayout>
        <FinancialReportList />
      </ReportListLayout>
    </ApolloProvider>
  );
}
