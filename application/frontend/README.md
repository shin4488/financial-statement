# investee フロントエンド（React SPA）

上場企業の財務 3 表を積み上げグラフ・ウォーターフォールグラフで表示する画面。
本番: https://investee.info

[financial-statement](https://github.com/shin4488/financial-statement) monorepo の
`application/frontend` ディレクトリ。設計ドキュメントと docker-compose 定義はリポジトリルート側にある。

## 技術スタック

| 項目           | 内容                                                          |
| -------------- | ------------------------------------------------------------- |
| ビルド・テスト | Vite（開発サーバ・本番ビルド）+ Vitest / TypeScript           |
| データ取得     | Apollo Client（GraphQL） + graphql-codegen（型の自動生成）    |
| UI             | MUI / recharts                                                |
| 状態管理       | 検索条件は URL クエリ、カルーセルの自動切替のみ Redux Toolkit |

## セットアップ

Node.js は `.nvmrc` のバージョンを使う（nvm 利用時はこのディレクトリで `nvm install && nvm use`）。

リポジトリルートで `docker compose up` すると、バックエンド・DB 込みで一括起動する
（画面は http://localhost:10000）。単体で動かす場合:

```bash
yarn install
```

```bash
yarn start
```

Docker で起動する場合も、ホスト側のエディタで型検査するには、このディレクトリで
`yarn install --frozen-lockfile` を実行する。Docker 内の `node_modules` は Linux 向けの
名前付きボリュームで、ホストには共有されない。ホスト側に依存がないと、エディタに
`react/jsx-runtime` が見つからない（ts2875）などのエラーが出る。

## GraphQL の型生成

バックエンドのスキーマ変更後に実行する。**バックエンドの起動は不要**
（`codegen.ts` の `schema` がコミット済みの `../backend/schema.graphql` を指しているため）:

```bash
npm run compile
```

`src/__generated__/` が更新される。クエリ文字列を変更したときも実行すること。
バックエンドのスキーマを変えた場合は、先に backend 側で `rake graphql:dump_schema` を実行して
`schema.graphql` を更新しておく。

## 検証

```bash
npx tsc --noEmit && npx eslint 'src/**/*.{ts,tsx}' && npx prettier --check 'src/**/*.{ts,tsx}'
```

```bash
yarn build
```

## 主要な構成

```
src/
  features/financialReports/     # 一覧ページ（Webアプリ固有）
    FinancialReportListPage.tsx  #   URLクエリ → GraphQL変数・無限スクロール
    components/                  #   カード・レイアウト（AppBar/検索/フッター）・BS→PL→CF→ROE・ROAの自動切替カルーセル
    api/                         #   クエリ定義と型
  shared/financialCharts/        # 汎用チャートキット（Chrome拡張と共有可能）
    StackedBarChart.tsx          #   BS・PL（積み上げ棒）
    WaterfallChart.tsx           #   CF（ウォーターフォール）
    colorRoles.ts                #   役割→色の対応（バックエンドのenumと同時に変更する契約）
  shared/financialIndicators/   # ROE・ROAの共有表示（Web・拡張）
  plugins/firebase/              # アナリティクス
```

**チャートは「科目」を知らない**（バックエンドが色の役割・ラベル・積み上げ順まで決めて返す）。
新しい会計基準・業種への対応でフロントを触る必要はない。設計意図はリポジトリルートの
`docs/guide/03_data_flow.md` を参照。
