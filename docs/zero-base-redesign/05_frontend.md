# フロントエンド実装詳細

## 0. 財務情報の違いをフロントで吸収する仕組み（設計意図）

会計基準・業種形式によって「何段積むか」「各段が何か」「どちらの棒に積むか」が全部違う。
これをフロントで吸収するために、**コンポーネントを増やすのではなく、データ契約を汎用化する**。
吸収メカニズムは次の6つで、以降のコードすべてがこのどれかを実装している:

| # | 仕組み | 吸収する差異 | 実装箇所 |
|---|---|---|---|
| 1 | セグメント駆動レンダリング（`bars[].segments[]` をそのまま積む。dataKeyのハードコードなし） | 段数・科目の違い（JGAAP=BS7段 / 銀行=7段だが別科目 / IFRS流動性配列=5段…） | StackedBarChart |
| 2 | `colorRole` 契約（意味ベースの色enum） | 「何色にすべきか」の知識。フロントは科目名でなく役割で塗る | colorRoles.ts |
| 3 | `amount`（描画高さ≥0）と `signedAmount`（実値）の分離 | 赤字・債務超過などマイナス値の表示（棒は正の高さで積み、値はツールチップで負を見せる） | API契約 |
| 4 | `spacer` セグメント（透明の詰め物） | 債務超過時の3本目バーの位置合わせ | StackedBarChart + colorRoles |
| 5 | `renderable: false + note` の第一級データ化 | 「この形式・この表は出せない」（例: 保険IFRSのPL、US GAAP全表） | ChartUnavailable |
| 6 | `kind: balance / flow` のステップ種別 | CFの残高（0起点）と増減（浮かせて描く）の描き分け + 為替差異の吸収 | WaterfallChart |

この結果、**新形式（例: 日本基準の保険業）を追加してもフロントの変更はゼロ**。
バックエンドが新しい `segments` の並びを返してくるだけで、同じコンポーネントが描画する。
具体的なデータが各層をどう流れるかは [07_data_flow_example.md](07_data_flow_example.md) を参照
（同じ `StackChart` 契約に武田(IFRS)と三菱UFJ(銀行)が乗る実データ例がある）。

## 0.5. 雛形と配線（最初にやること）

現行スタック（CRA + craco + TypeScript）を踏襲する前提。既存の `src/` を段階的に置き換える。

```bash
cd application/frontend

# 依存の追加はなし（@apollo/client / graphql / recharts / react-router-dom は導入済み）。
# 削除するもの（ゼロベース化で不要になる。一覧ページ移行が終わってから外す）:
#   @reduxjs/toolkit react-redux（URLクエリ同期に置き換え・§9）

mkdir -p src/features/financialReports/{api,components}
```

`codegen.ts`（graphql-codegen設定。スキーマファイル参照方式 — バックエンド起動不要にする）:

```ts
// codegen.ts（リポジトリ直下。既存ファイルがあれば置き換え）
import type { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  // バックエンドで `rake graphql:dump_schema` してコミットされた schema.graphql を参照する
  // （docs/improvements.md 1-5。submodule構成なら相対パスで届く）
  schema: '../backend/schema.graphql',
  documents: ['src/features/**/*.query.ts'],
  generates: {
    'src/__generated__/': {
      preset: 'client',
      config: {
        scalars: { BigInt: 'number' },  // §3参照。文字列で返る実装だった場合はカスタムパーサに変更
      },
    },
  },
};
export default config;
```

Apollo Clientの初期化（`src/plugins/apollo/client.ts`）:

```ts
// src/plugins/apollo/client.ts
import { ApolloClient, InMemoryCache, HttpLink } from '@apollo/client';

export const apolloClient = new ApolloClient({
  // nginx経由の相対パス（web/sites-enabledで /api → appserver にプロキシされる）。
  // ホストをハードコードしないことで開発(localhost:10000)と本番(investee.info)を同一コードにする
  link: new HttpLink({ uri: '/api/graphql' }),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          // 無限スクロール: offsetが違う結果を同一リストに連結する
          financialReports: {
            keyArgs: ['stockCodes', 'operatingCfSign', 'investingCfSign', 'financingCfSign'],
            merge: (existing = [], incoming) => [...existing, ...incoming],
          },
        },
      },
    },
  }),
});
```

`App.tsx` のルーティング:

```tsx
// src/App.tsx
import { ApolloProvider } from '@apollo/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { HelmetProvider } from 'react-helmet-async';  // 企業別URL対応（improvements 2-1）まで不要なら省略可
import { apolloClient } from '@/plugins/apollo/client';
import { FinancialReportListPage } from '@/features/financialReports/FinancialReportListPage';

export default function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <HelmetProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<FinancialReportListPage />} />
          </Routes>
        </BrowserRouter>
      </HelmetProvider>
    </ApolloProvider>
  );
}
```

## 1. ディレクトリ構成（feature-based）

```
src/
  features/financialReports/
    api/
      financialReports.query.ts      # GraphQLドキュメント（codegen対象）
      types.ts                       # codegen生成型のre-export
    components/
      colorRoles.ts                  # 仕組み2: colorRole→色のマップ（バックエンドとの契約）
      StackedBarChart.tsx            # 仕組み1,3,4: 汎用積み上げ棒（BS/PL共用）
      WaterfallChart.tsx             # 仕組み6: 汎用ウォーターフォール（CF）
      ChartUnavailable.tsx           # 仕組み5: 表示不可の代替
      ReportCard.tsx                 # 1企業1期分のカード
      SearchForm.tsx                 # 検索フォーム（URLクエリ同期・CFプリセット）
    FinancialReportListPage.tsx      # 一覧ページ（無限スクロール）
  plugins/apollo/client.ts
```

状態管理は Apollo キャッシュ + Reactローカルstate（検索条件はURLクエリに同期）。
Reduxは導入しない。現行アプリでのRedux用途はフィルタ条件の共有のみで、
URLクエリ同期の方が「検索結果をURLで共有できる」というSEO/UX上の利点も兼ねるため。

## 2. データ契約（概念の説明。実ファイルは§9の types.ts）

バックエンドと合意している構造は以下。**この形の型を手書きはしない**——
実際の `api/types.ts` はcodegen生成型からの導出で作る（§9参照。スキーマ変更時に型ズレが起きないため）。
ここではフィールドの意味・制約をコメント付きで固定する:

```ts
// バックエンドの Charts::Segment/Bar/StackChart（04参照）と1:1対応。
// フロントはこの構造の「意味」を解釈しない。並び順・ラベル・色役割はバックエンドが決定済み。
export interface Segment {
  key: string;          // バー内で一意。Reactのkey・recharts dataKeyに使う
  label: string;        // 表示ラベル（日本語）。フロントに科目辞書を持たない意図でAPIが直接返す
  amount: number;       // 描画高さ。常に >= 0（仕組み3）
  signedAmount: number; // 実値。ツールチップはこちらを表示（赤字は負で届く）
  ratio: number | null; // %。nullは「表示しない」（spacer等）
  colorRole: string;    // colorRoles.tsのキー（仕組み2）
}
export interface StackBar { label: string; segments: Segment[] }
export interface StackChart { renderable: boolean; note: string | null; bars: StackBar[] }

export interface WaterfallStep {
  key: string;
  label: string;
  amount: number;             // こちらは符号付き（増減をそのまま表す）
  kind: 'balance' | 'flow';   // balance=残高（0起点） / flow=増減（累積位置から浮かせる）
}
export interface WaterfallChart { renderable: boolean; note: string | null; steps: WaterfallStep[] }
```

## 3. GraphQLクエリ（内容の説明。実ファイルは§9の financialReports.query.ts）

```graphql
query FinancialReports(
  $limit: Int!, $offset: Int!, $stockCodes: [String!],
  $operatingCfSign: NumberSign, $investingCfSign: NumberSign, $financingCfSign: NumberSign
) {
  financialReports(
    limit: $limit, offset: $offset, stockCodes: $stockCodes,
    operatingCfSign: $operatingCfSign, investingCfSign: $investingCfSign, financingCfSign: $financingCfSign
  ) {
    id
    stockCode
    companyName
    fiscalYearStartDate
    fiscalYearEndDate
    accountingStandard   # バッジ表示のみに使う。描画分岐には使わない（使い出したら設計が壊れているサイン）
    consolidationType
    balanceSheet { ...StackChartFields }
    profitLoss   { ...StackChartFields }
    cashFlow { renderable note steps { key label amount kind } }
  }
}
fragment StackChartFields on StackChart {
  renderable
  note
  bars { label segments { key label amount signedAmount ratio colorRole } }
}
```

codegen設定は§0.5の `codegen.ts` を参照（BigIntをnumberにマップする理由:
日本企業の最大値=三菱UFJの総資産431兆円=4.3e14 は Number.MAX_SAFE_INTEGER(9e15) 内に収まる）。

## 4. colorRoles.ts（仕組み2: 色の契約）

```ts
// src/features/financialReports/components/colorRoles.ts
// バックエンドの Charts::Builders が発行する colorRole の全量。
// 「科目→色」でなく「役割→色」にすることで、新形式の科目（例: 銀行の貸出金）にも
// 既存の役割（asset2）を割り当てるだけで一貫した見た目になる。
// このキー一覧はバックエンドと共有する契約なので、追加時は04のenumと同時に変更すること。
export const colorByRole: Record<string, string> = {
  asset1: '#A1C2F1',      // 資産・第1階層（流動資産/現金系）
  asset2: '#5A96E3',      // 資産・第2階層
  asset3: '#7286D3',
  asset4: '#576CBC',
  liability1: '#FEBBCC',  // 負債・第1階層
  liability2: '#E48586',
  equity: '#8EC3B0',      // 資本・純資産
  revenue: '#8EC3B0',     // 収益
  expense1: '#FEBBCC',    // 費用（原価・経常費用・営業費用）
  expense2: '#E48586',    // 費用（販管費）
  expense3: '#D77FA1',    // 費用（導出項目: その他損益純額など）
  profit: '#6196A6',      // 利益
  loss: '#BF3131',        // 損失・債務超過
  spacer: 'transparent',  // 仕組み4: 債務超過バーの位置合わせ用詰め物
};
export const stackLabelColor = '#FFFFFF';
```

## 5. StackedBarChart.tsx（仕組み1,3,4の実装）

```tsx
// src/features/financialReports/components/StackedBarChart.tsx
import { Bar, BarChart, LabelList, ResponsiveContainer, Tooltip, YAxis } from 'recharts';
import { colorByRole, stackLabelColor } from './colorRoles';
import { ChartUnavailable } from './ChartUnavailable';
import type { StackChart, Segment } from '../api/types';

// rechartsは「行の配列 × 固定dataKey」を要求するが、こちらは「バーごとに異なるセグメント列」を
// 描きたい。そこで行 = バー、列 = 全バーのセグメントkeyの和集合、に変換する。
// あるバーに存在しないkeyの値はundefinedになり、rechartsはその行では何も描かない。
// → 「借方バーにだけ売上原価がある」「3本目の債務超過バーにだけspacerがある」を自然に表現できる。
type Row = { name: string; __segments: Record<string, Segment> } & Record<string, number>;

export function toRows(chart: StackChart): { rows: Row[]; columns: { key: string; colorRole: string }[] } {
  const columns: { key: string; colorRole: string }[] = [];
  const rows = chart.bars.map((bar) => {
    // __segments: この行のセグメントメタ（ラベル・実値・比率）。
    // ツールチップとラベルはここから引くため、フロントは科目辞書を一切持たない（仕組み1の核心）
    const row = { name: bar.label, __segments: {} as Record<string, Segment> } as Row;
    bar.segments.forEach((s) => {
      if (!columns.some((c) => c.key === s.key)) {
        columns.push({ key: s.key, colorRole: s.colorRole });
      }
      row[s.key] = s.amount; // 描画は常に正のamount（仕組み3）
      row.__segments[s.key] = s;
    });
    return row;
  });
  // columnsの順序 = バー出現順×セグメント出現順。バックエンドが決めた積み上げ順が
  // そのまま描画順になる（APIの配列順序は契約の一部）
  return { rows, columns };
}

export function StackedBarChart({ chart }: { chart: StackChart }) {
  if (!chart.renderable) return <ChartUnavailable note={chart.note} />;
  const { rows, columns } = toRows(chart);

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={rows}>
        {/* Y軸反転: 積み上げを「上から下」に描く（BSの「上=流動・下=純資産」の慣習を保つ）。
            domainのdataMaxは最も高いバー（=貸借どちらか）に全バーの縮尺を合わせる */}
        <YAxis reversed hide domain={[0, 'dataMax']} />
        <Tooltip
          cursor={false}
          labelFormatter={() => ''} // 行インデックスが出てしまうため空に
          formatter={(_value, key, item) => {
            const s: Segment | undefined = item?.payload?.__segments?.[key as string];
            // spacerはユーザーに見せる情報ではないのでツールチップから隠す（仕組み4）
            if (!s || s.colorRole === 'spacer') return [null, null];
            // 表示はsignedAmount: 債務超過の純資産は「-2,000,000円」のように負で見せる（仕組み3）
            return [`${s.signedAmount.toLocaleString()}円`, s.label];
          }}
        />
        {columns.map(({ key, colorRole }) => (
          <Bar key={key} dataKey={key} stackId="a" fill={colorByRole[colorRole]} isAnimationActive={false}>
            <LabelList
              dataKey={key}
              position="center"
              content={(props) => {
                const { x, y, width, height, index } = props as unknown as {
                  x: number; y: number; width: number; height: number; index: number };
                const s = rows[index]?.__segments[key];
                // ratio=nullは「ラベルなし」の契約。高さ14px未満は物理的に潰れるため抑制
                if (!s || s.ratio == null || height < 14) return null;
                return (
                  <text x={x + width / 2} y={y + height / 2} textAnchor="middle"
                        dominantBaseline="central" fill={stackLabelColor} fontSize={12}>
                    {`${s.label}: ${s.ratio}%`}
                  </text>
                );
              }}
            />
          </Bar>
        ))}
      </BarChart>
    </ResponsiveContainer>
  );
}
```

**このコンポーネントが吸収する実例**（同じコードで描けるもの）:

| 入力 | バー構成 |
|---|---|
| JGAAP一般のBS | 借方4段 / 貸方3段（+債務超過なら3本目） |
| 銀行のBS | 借方4段（現金預け金・貸出金・有価証券・その他）/ 貸方3段（預金・その他負債・純資産） |
| IFRS流動性配列のBS | 借方2段 / 貸方2段+資本 |
| 武田のPL（赤字） | 借方3段 / 貸方2段（収益+税引前損失） |
| 銀行のPL | 借方2段（経常費用+経常利益）/ 貸方1段（経常収益） |

## 6. WaterfallChart.tsx（仕組み6の実装）

```tsx
// src/features/financialReports/components/WaterfallChart.tsx
import { Bar, BarChart, Cell, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { ChartUnavailable } from './ChartUnavailable';
import type { WaterfallChart as WaterfallChartData, WaterfallStep } from '../api/types';

const FLOW_POSITIVE = '#8EC3B0';
const FLOW_NEGATIVE = '#E48586';
const BALANCE = '#5A96E3';

type Row = { name: string; base: number; span: number; step: WaterfallStep };

// ウォーターフォールは「透明のベース + 実バー」の2段積みで浮かせて描く。
// kind=balance（期首・期末残高）: 0起点で独立に描く。累積位置で描かない意図は、
//   CF計算書には為替換算差額があり「期首+3区分の合計 ≠ 期末」になり得るため
//   （実例: 三菱UFJで差690,400百万円。07参照）。期末を実測値で0から描けばこの差異は自然に吸収される。
// kind=flow（3区分）: 直前までの累積位置から増減分だけ浮かせる。負の増減は下向き。
export function toRows(steps: WaterfallStep[]): Row[] {
  let cumulative = 0;
  return steps.map((step) => {
    if (step.kind === 'balance') {
      cumulative = step.amount; // 残高で累積をリセット（期首から始まる契約）
      return { name: step.label, base: 0, span: step.amount, step };
    }
    const start = cumulative;
    cumulative += step.amount;
    // 銀行の営業CF（-23兆）のように累積が負に落ちてもmin/absで正しく描ける
    return { name: step.label, base: Math.min(start, cumulative), span: Math.abs(step.amount), step };
  });
}

export function WaterfallChart({ chart }: { chart: WaterfallChartData }) {
  if (!chart.renderable) return <ChartUnavailable note={chart.note} />;
  const rows = toRows(chart.steps);

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={rows}>
        <XAxis dataKey="name" tick={{ fontSize: 10 }} interval={0} />
        {/* domain自動: 累積が負になるケース（銀行）で0より下も描画させる */}
        <YAxis hide domain={['auto', 'auto']} />
        <ReferenceLine y={0} stroke="#999" />
        <Tooltip
          cursor={false}
          labelFormatter={() => ''}
          formatter={(_v, _k, item) => {
            const step: WaterfallStep = item?.payload?.step;
            // 実値（符号付き）を表示。描画用のbase/spanは見せない
            return [`${step.amount.toLocaleString()}円`, step.label];
          }}
        />
        <Bar dataKey="base" stackId="w" fill="transparent" isAnimationActive={false} />
        <Bar dataKey="span" stackId="w" isAnimationActive={false}>
          {rows.map((row) => (
            <Cell key={row.step.key}
                  fill={row.step.kind === 'balance' ? BALANCE
                        : row.step.amount >= 0 ? FLOW_POSITIVE : FLOW_NEGATIVE} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
```

**データ例**（三菱UFJ。`toRows` の出力。単位: 百万円）:

```ts
// 入力steps: 期首109,095,437 / 営業-23,064,420 / 投資+4,473,959 / 財務-1,149,876 / 期末90,045,500
[
  { name: '期首残高', base: 0,          span: 109_095_437 },  // balance: 0起点
  { name: '営業CF',   base: 86_031_017, span: 23_064_420 },   // 109,095,437→86,031,017に下降。base=min
  { name: '投資CF',   base: 86_031_017, span: 4_473_959 },    // 上昇。base=下端
  { name: '財務CF',   base: 89_355_100, span: 1_149_876 },    // 下降
  { name: '期末残高', base: 0,          span: 90_045_500 },   // balance: 為替差異690,400を吸収して実測値で描く
]
```

## 7. ChartUnavailable.tsx（仕組み5）

```tsx
// src/features/financialReports/components/ChartUnavailable.tsx
// 「表示不可」は正常系（保険IFRSのPL・US GAAP等）。エラーバウンダリではなくデータとして描く。
// noteはバックエンドが形式判定の文脈を知った上で書いた文言なので、そのまま出す
export function ChartUnavailable({ note }: { note?: string | null }) {
  return (
    <div className="chart-unavailable">
      {note ?? 'データがない、または表示対応していないデータです。'}
    </div>
  );
}
```

## 8. ReportCard.tsx

```tsx
// src/features/financialReports/components/ReportCard.tsx
import { StackedBarChart } from './StackedBarChart';
import { WaterfallChart } from './WaterfallChart';
import type { FinancialReport } from '../api/types';

// accountingStandard/consolidationTypeの用途はバッジ表示のみ。
// 「IFRSだからこのコンポーネント」という分岐を書かないことがこの設計の規律
const standardBadge: Record<string, string> = {
  japan_gaap: '日本基準', ifrs: 'IFRS', us_gaap: '米国基準',
};

export function ReportCard({ report }: { report: FinancialReport }) {
  return (
    <section className="report-card">
      <header>
        <h3>{report.companyName}（{report.stockCode}）</h3>
        <span>{report.fiscalYearStartDate} 〜 {report.fiscalYearEndDate}</span>
        <span className="badge">{standardBadge[report.accountingStandard]}</span>
        <span className="badge">{report.consolidationType === 'consolidated' ? '連結' : '単体'}</span>
      </header>
      <div className="charts">
        <div><h4>貸借対照表</h4><StackedBarChart chart={report.balanceSheet} /></div>
        <div><h4>損益計算書</h4><StackedBarChart chart={report.profitLoss} /></div>
        <div><h4>キャッシュフロー</h4><WaterfallChart chart={report.cashFlow} /></div>
      </div>
    </section>
  );
}
```

## 9. FinancialReportListPage.tsx（一覧ページ・完全版）

検索条件はURLクエリに持つ（結果画面をURLで共有・ブックマックできる。Redux廃止の代替 + SEO/UX）。
無限スクロールは導入済みの `react-infinite-scroller` を使う。

```tsx
// src/features/financialReports/FinancialReportListPage.tsx
import { useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery } from '@apollo/client';
import InfiniteScroll from 'react-infinite-scroller';
import { FINANCIAL_REPORTS_QUERY, PAGE_SIZE } from './api/financialReports.query';
import { ReportCard } from './components/ReportCard';
import { SearchForm, CF_PRESETS, type CfPresetKey } from './components/SearchForm';

// URLクエリ（例: /?codes=7203,4502&cf=excellent）→ GraphQL変数
function useQueryVariables() {
  const [searchParams] = useSearchParams();
  return useMemo(() => {
    const codes = searchParams.get('codes')?.split(',').filter(Boolean) ?? null;
    const preset = CF_PRESETS[(searchParams.get('cf') ?? '') as CfPresetKey];
    return {
      limit: PAGE_SIZE,
      offset: 0,
      stockCodes: codes,
      operatingCfSign: preset?.operating ?? null,
      investingCfSign: preset?.investing ?? null,
      financingCfSign: preset?.financing ?? null,
    };
  }, [searchParams]);
}

export function FinancialReportListPage() {
  const variables = useQueryVariables();
  const { data, loading, fetchMore } = useQuery(FINANCIAL_REPORTS_QUERY, {
    variables,
    notifyOnNetworkStatusChange: true,  // fetchMore中もloadingを反映させる
  });
  const reports = data?.financialReports ?? [];
  // 「最後のページ」の判定はAPIに件数フィールドを増やさず、
  // 「直近の取得件数がページサイズ未満なら終端」で行う（一覧APIをシンプルに保つ意図）
  const hasMore = reports.length % PAGE_SIZE === 0 && reports.length > 0;

  return (
    <main>
      <SearchForm />
      <InfiniteScroll
        loadMore={() => {
          if (loading) return;  // 多重発火ガード（scroller側は連打してくる）
          // offsetだけ進める。結果の連結はApolloのtypePolicies（§0.5のmerge）が行う
          fetchMore({ variables: { ...variables, offset: reports.length } });
        }}
        hasMore={hasMore}
        loader={<div key="loader">読み込み中…</div>}
      >
        {reports.map((r) => (
          <ReportCard key={r.id} report={r} />
        ))}
      </InfiniteScroll>
      {!loading && reports.length === 0 && <p>条件に一致する企業がありません。</p>}
    </main>
  );
}
```

```tsx
// src/features/financialReports/components/SearchForm.tsx
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';

// CFパターンのプリセット（現行アプリの cashFlowTypeRequestMap と同じ発想）。
// キーがURLクエリ値になる（例: ?cf=excellent）
export const CF_PRESETS = {
  excellent: { label: '優良型（営業+ 投資- 財務-）', operating: 'POSITIVE', investing: 'NEGATIVE', financing: 'NEGATIVE' },
  aggressive: { label: '積極投資型（営業+ 投資- 財務+）', operating: 'POSITIVE', investing: 'NEGATIVE', financing: 'POSITIVE' },
  restructuring: { label: '事業再構築型（営業+ 投資+ 財務-）', operating: 'POSITIVE', investing: 'POSITIVE', financing: 'NEGATIVE' },
  danger: { label: '危険型（営業- 投資+ 財務+）', operating: 'NEGATIVE', investing: 'POSITIVE', financing: 'POSITIVE' },
} as const;
export type CfPresetKey = keyof typeof CF_PRESETS;

export function SearchForm() {
  const [searchParams, setSearchParams] = useSearchParams();
  // 入力途中の値はローカルstate、確定した検索条件だけがURL（=クエリ変数）になる
  const [codesInput, setCodesInput] = useState(searchParams.get('codes') ?? '');
  const cf = searchParams.get('cf') ?? '';

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const next = new URLSearchParams(searchParams);
    // 4桁数字以外は捨てる（0パディング等の証券コード仕様はバックエンドの責務なのでここでは触らない）
    const codes = codesInput.split(/[,\s]+/).filter((c) => /^\d{4}$/.test(c));
    codes.length ? next.set('codes', codes.join(',')) : next.delete('codes');
    setSearchParams(next);
  };

  const selectCf = (value: string) => {
    const next = new URLSearchParams(searchParams);
    value ? next.set('cf', value) : next.delete('cf');
    setSearchParams(next);
  };

  return (
    <form onSubmit={submit} className="search-form">
      <input
        value={codesInput}
        onChange={(e) => setCodesInput(e.target.value)}
        placeholder="証券コード4桁（カンマ区切りで複数可）"
        inputMode="numeric"
      />
      <button type="submit">検索</button>
      <select value={cf} onChange={(e) => selectCf(e.target.value)}>
        <option value="">CFパターン: 指定なし</option>
        {Object.entries(CF_PRESETS).map(([key, preset]) => (
          <option key={key} value={key}>{preset.label}</option>
        ))}
      </select>
    </form>
  );
}
```

```ts
// src/features/financialReports/api/financialReports.query.ts
// graphql() は codegen（client-preset）が生成するタグ関数。
// クエリ文字列を変更したら `npm run compile` で型を再生成すること
import { graphql } from '@/__generated__';

export const PAGE_SIZE = 20;

export const FINANCIAL_REPORTS_QUERY = graphql(`
  query FinancialReports(
    $limit: Int!, $offset: Int!, $stockCodes: [String!],
    $operatingCfSign: NumberSign, $investingCfSign: NumberSign, $financingCfSign: NumberSign
  ) {
    financialReports(
      limit: $limit, offset: $offset, stockCodes: $stockCodes,
      operatingCfSign: $operatingCfSign, investingCfSign: $investingCfSign, financingCfSign: $financingCfSign
    ) {
      id
      stockCode
      companyName
      fiscalYearStartDate
      fiscalYearEndDate
      accountingStandard
      consolidationType
      balanceSheet { ...StackChartFields }
      profitLoss { ...StackChartFields }
      cashFlow {
        renderable
        note
        steps { key label amount kind }
      }
    }
  }
`);

export const STACK_CHART_FRAGMENT = graphql(`
  fragment StackChartFields on StackChart {
    renderable
    note
    bars {
      label
      segments { key label amount signedAmount ratio colorRole }
    }
  }
`);
```

```ts
// src/features/financialReports/api/types.ts
// コンポーネントのpropsに使う型。codegenの生成型（FinancialReportsQuery）から導出し、
// 手書きの型定義を持たない（スキーマ変更時に型ズレが起きない）
import type { FinancialReportsQuery } from '@/__generated__/graphql';

export type FinancialReport = FinancialReportsQuery['financialReports'][number];
export type StackChart = FinancialReport['balanceSheet'];
export type StackBar = StackChart['bars'][number];
export type Segment = StackBar['segments'][number];
export type WaterfallChart = FinancialReport['cashFlow'];
export type WaterfallStep = WaterfallChart['steps'][number];
```

最低限のスタイル（`src/index.css` に追記。MUIに寄せる場合は置き換えてよい）:

```css
.search-form { display: flex; gap: 8px; padding: 16px; }
.report-card { border: 1px solid #e0e0e0; border-radius: 8px; margin: 16px; padding: 16px; }
.report-card .charts { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
.report-card .badge { background: #eef; border-radius: 4px; padding: 2px 8px; margin-left: 8px; font-size: 12px; }
.chart-unavailable { display: flex; align-items: center; justify-content: center;
  height: 300px; color: #757575; background: #fafafa; border-radius: 4px; text-align: center; }
```

## 10. 新形式追加時にフロントが無変更で済む根拠（総括）

| 形式追加で変わり得るもの | 吸収する契約 |
|---|---|
| 段数・科目名・積み上げ順 | `segments[]` の配列（仕組み1）。keyもlabelもAPI由来 |
| 色 | `colorRole`（仕組み2）。既存roleへの割当はバックエンドの責務 |
| マイナス値の科目 | `amount`/`signedAmount` 分離（仕組み3） |
| 表せない表 | `renderable/note`（仕組み5） |
| 唯一フロント変更が要るケース | 新しい `colorRole` 値の追加時（colorRoles.tsに1行）。これは意図的な契約変更 |

## 11. テスト

- `toRows`（両チャート）は純関数なのでユニットテストで網羅:
  - セグメントkey列の順序安定性（バー出現順）
  - 存在しないkeyの行でundefinedになること（=描画されない）
  - spacerのツールチップ抑止
  - waterfallの累積計算（銀行の負累積ケース: 上記データ例をそのままfixtureに）
- Storybook（なければfixture一覧ページで代替）に07のAPIレスポンスJSON（6社分）を置き、
  4形式 × 債務超過 × 表示不可のビジュアルを一括確認。**バックエンドと結合せずに**
  チャートの見た目を検証できるのが、チャート構造をデータ契約にしたもう1つの利点
