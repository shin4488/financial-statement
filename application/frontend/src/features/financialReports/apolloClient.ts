import { ApolloClient, InMemoryCache } from '@apollo/client';

// ApolloClientService（アプリ共有のシングルトン）を使わない理由:
// 無限スクロールの結果連結にtypePolicies（merge）が必要で、共有シングルトンの
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
            // 単純なconcatでなくoffset位置に書き込む理由: 同じoffsetを二重に取得した場合
            // （再レンダリングとスクロールの競合など）にリストが重複しないようにするため
            merge: (
              existing: unknown[] = [],
              incoming: unknown[],
              { args }: { args: Record<string, unknown> | null },
            ) => {
              const offset = typeof args?.offset === 'number' ? args.offset : 0;
              const merged = existing.slice(0);
              incoming.forEach((item, index) => {
                merged[offset + index] = item;
              });
              return merged;
            },
          },
        },
      },
    },
  }),
});
