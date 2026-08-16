# financial-statement（investee）

上場企業の財務3表（BS/PL/CF）をEDINETからXBRLで取得し、PostgreSQLに保存、Reactでグラフ可視化するWebアプリ。本番: https://investee.info

## リポジトリ構成（monorepo）

```
application/backend    # Rails APIサーバ
application/frontend   # React SPA
web/                   # nginx設定
database/ cache/       # PostgreSQL / Redis のDocker設定
docs/                  # 設計ドキュメント
docker-compose.yml     # 全体起動（web:10000, api:20000）
```

- 単一リポジトリ（monorepo）。2026-08にgit submodule構成から移行済みで、旧backend/frontendリポジトリはアーカイブ（履歴はこのリポジトリに統合済み）
- CIは `.github/workflows/` の backend-ci / frontend-ci（`paths:` フィルタで変更のあった側だけ実行）
- ローカル実行: `docker compose up`（DB初期化は `database/init/`）。バックエンド単体はrbenvのruby 3.4.10 + `bundle exec`で動く（DBはdocker側が必要）

## バックエンド（application/backend）

- Rails 7 + GraphQL（エンドポイント `/graphql`）+ Sidekiq（sidekiq-cronで日次取込）
- データ取込の流れ: `Ingestion::DailyIngestionService`（`DailyIngestionJob`が毎日2:00に実行）→ `Edinet::Client`（EDINET API→zip）→ `Xbrl::Document`（パース）→ `Ingestion::ReportIngester`（形式判定・Extractor・`Disclosure::*` upsert）
- 参照系: `Types::QueryType#financial_reports` → `Resolvers::FinancialReports`→ `Disclosure::SearchQuery` + `Charts::BuilderRegistry`
- 環境変数は `config/application.yml`（figaro形式・gitignore済みのローカルファイル。シークレットを含むため**このファイルの中身をコミット・ログ・ドキュメントに転記しないこと**）
- EDINET APIはリクエスト過多で403になるため**同期・逐次実行が前提**（並列化しない）
- 公開・未認証エンドポイントのため、スキーマに `max_complexity` / `max_depth` の上限がある（`app/graphql/financial_statement_schema.rb`。フィールドを増やすときは上限に収まるか確認する）

## フロントエンド（application/frontend）

- CRA(craco) + TypeScript + Apollo Client + Redux Toolkit + MUI + recharts
- GraphQLの型生成: `npm run compile`（graphql-codegen。backendのコミット済み`schema.graphql` を参照するためバックエンド起動は不要）
- 主要ページ: `src/features/financialReports/`、汎用チャート: `src/shared/financialCharts/`

## ドメイン知識（重要）

- 証券コードはEDINET上5桁、UI上は4桁（末尾0を付けて検索する）
- 会計基準はDEIタグ `AccountingStandardsDEI`（Japan GAAP / US GAAP / IFRS）で判定
- **IFRS企業の連結財務諸表は `jpigp_cor` 名前空間**（日本基準は `jppfs_cor`）。現行実装はIFRS（`ifrs_classified` / `ifrs_liquidity`）と日本基準の銀行にも対応済み
- IFRS企業でも**単体財務諸表は日本基準**でタグ付けされる
- 銀行・保険など特定業種は日本基準でも別フォーマット（業種DEIコード bnk/INS等）。銀行は対応済み、保険・米国基準は `unsupported`（グラフの代わりに説明文を出す正常系）
- **実装済みアーキテクチャの正は `docs/guide/` の03章（全体像・4層設計・データモデル）と04章（取込・チャート生成・API）**。旧系統（SecurityReport系）のコードは削除済みで、`security_reports`テーブルのみ凍結保管（`docs/guide/08_unused_but_kept.md`）
- **XBRLタグを扱う作業の前に必ず`docs/guide/07_taxonomy_mapping.md`（6社実測データ）を読むこと**

## 改善バックログ

DX/SEO/AI活用の改善候補は `docs/improvements.md` に整理されている。

## リポジトリ理解ガイド

ドキュメントの本体は `docs/guide/`（README.mdが目次）。学ぶ章（01〜06: ドメイン知識→仕様→全体像と設計→バックエンド→フロントエンド→開発と運用。技術の基礎説明と設計判断の「なぜ」は03〜05章に統合されている）+ 資料（07〜08: タグ対応表と実測データ・使っていないが残しているもの）の構成。
