# investee フロントエンド（React SPA）

上場企業の財務3表を積み上げグラフ・ウォーターフォールグラフで表示する画面。
本番: https://investee.info

**このリポジトリは親リポジトリ [financial-statement](https://github.com/shin4488/financial-statement) の
git submodule**（`application/frontend`）。設計ドキュメントとdocker-compose定義は親リポジトリ側にある。

## 技術スタック

| 項目 | 内容 |
|---|---|
| ビルド | Create React App + craco / TypeScript |
| データ取得 | Apollo Client（GraphQL） + graphql-codegen（型の自動生成） |
| UI | MUI / recharts |
| 状態管理 | 検索条件はURLクエリ、カルーセルの自動切替のみRedux Toolkit |

## セットアップ

親リポジトリで `docker compose up` すると、バックエンド・DB込みで一括起動する
（画面は http://localhost:10000）。単体で動かす場合:

```bash
yarn install
```

```bash
yarn start
```

## GraphQLの型生成

バックエンドのスキーマ変更後に実行する。**バックエンドの起動が必要**
（`codegen.ts` の `schema` がAPIのエンドポイントを指しているため）:

```bash
docker compose exec appfront npm run compile
```

`src/__generated__/` が更新される。クエリ文字列を変更したときも実行すること。

## 検証

```bash
npx tsc --noEmit && npx eslint 'src/**/*.{ts,tsx}' && npx prettier --check 'src/**/*.{ts,tsx}'
```

```bash
CI=false yarn build
```

## 主要な構成

```
src/
  features/financialReports/     # 一覧ページ（Webアプリ固有）
    FinancialReportListPage.tsx  #   URLクエリ → GraphQL変数・無限スクロール
    components/                  #   カード・レイアウト（AppBar/検索/フッター）
    api/                         #   クエリ定義と型
  shared/financialCharts/        # 汎用チャートキット（Chrome拡張と共有可能）
    StackedBarChart.tsx          #   BS・PL（積み上げ棒）
    WaterfallChart.tsx           #   CF（ウォーターフォール）
    colorRoles.ts                #   役割→色の対応（バックエンドのenumと同時に変更する契約）
  components/appCarousel/        # BS→PL→CFの自動切替カルーセル
  plugins/firebase/              # アナリティクス
```

**チャートは「科目」を知らない**（バックエンドが色の役割・ラベル・積み上げ順まで決めて返す）。
新しい会計基準・業種への対応でフロントを触る必要はない。設計意図は親リポジトリの
`docs/architecture/04_frontend.md` を参照。

旧一覧ページ（`src/pages/financialStatementList/` と `src/components/*BarChart/`）は
停止・残置中。削除手順は `docs/architecture/07_legacy_cleanup.md`。
