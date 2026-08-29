import { ApolloClient, InMemoryCache } from '@apollo/client';

// 無限スクロールの結果連結。単純なconcatにしない理由: 同じoffsetを二重に取得した場合
// （再レンダリングとスクロールの競合など）にリストが重複しないよう、offset位置へ上書きする。
// offsetが手元のリストより先を指す場合（途中ページの取得失敗など）は末尾に詰める:
// 疎（歯抜け）の配列を作ると、lengthが実件数と乖離して終端判定（30の倍数）を狂わせるため
export function mergeFinancialReports(
  existing: unknown[] | undefined,
  incoming: unknown[],
  offset: number,
): unknown[] {
  const merged = existing ? existing.slice(0) : [];
  const start = Math.min(offset, merged.length);
  incoming.forEach((item, index) => {
    merged[start + index] = item;
  });
  return merged;
}

// アプリ全体で共有するApolloクライアントにしない理由:
// 無限スクロールの結果連結にtypePolicies（merge）が必要で、共有クライアントの
// キャッシュ設定を変えると他ページに波及するため、このfeature専用クライアントを持つ
export const financialReportsClient = new ApolloClient({
  // nginx経由の相対パス。ホストをハードコードしないことで開発と本番を同一コードにする
  uri: '/api/graphql',
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          financialReports: {
            // offset以外の検索条件が同じ結果を同一リストとして連結する（無限スクロール）
            keyArgs: [
              'stockCodes',
              'operatingCfSign',
              'investingCfSign',
              'financingCfSign',
            ],
            merge: (
              existing: unknown[] = [],
              incoming: unknown[],
              { args }: { args: Record<string, unknown> | null },
            ) =>
              mergeFinancialReports(
                existing,
                incoming,
                typeof args?.offset === 'number' ? args.offset : 0,
              ),
          },
        },
      },
    },
  }),
});
