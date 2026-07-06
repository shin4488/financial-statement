# financial-statement（investee）

上場企業の財務3表（BS/PL/CF）をEDINETからXBRLで取得し、PostgreSQLに保存、
Reactでグラフ可視化するWebアプリ。本番: https://investee.info

## リポジトリ構成（git submodule注意）

```
application/backend    # Rails APIサーバ（★別リポジトリのsubmodule）
application/frontend   # React SPA（★別リポジトリのsubmodule）
web/                   # nginx設定
database/ cache/       # PostgreSQL / Redis のDocker設定
docs/                  # 設計ドキュメント（このリポジトリ直下）
docker-compose.yml     # 全体起動（web:10000, api:20000）
```

- **submodule内の変更はそれぞれのリポジトリで別コミットになる。** 親リポジトリでは
  submoduleのハッシュ更新コミットが別途必要
- ローカル実行: `docker compose up`（DB初期化は `database/init/`）。
  バックエンド単体はrbenvのruby 3.2.2 + `bundle exec`で動く（DBはdocker側が必要）

## バックエンド（application/backend）

- Rails 7 + GraphQL（エンドポイント `/graphql`）+ Sidekiq（sidekiq-cronで日次取込）
- データ取込の流れ: `SecurityReport::SubscriberService`（EDINET API→zip→XBRL）
  → `SecurityReport::ReaderRepository`（XBRLパース）→ `Company`/`SecurityReport` upsert
- 参照系: `Types::QueryType#company_financial_statements` → `SecurityReport::FetcherService`
- 環境変数は `config/application.yml`（figaro形式・gitignore済みのローカルファイル。
  シークレットを含むため**このファイルの中身をコミット・ログ・ドキュメントに転記しないこと**）
- EDINET APIはリクエスト過多で403になるため**同期・逐次実行が前提**（並列化しない）

## フロントエンド（application/frontend）

- CRA(craco) + TypeScript + Apollo Client + Redux Toolkit + MUI + recharts
- GraphQLの型生成: `npm run compile`（graphql-codegen。バックエンド起動が必要）
- 主要ページ: `src/pages/financialStatementList/`、チャート: `src/components/*BarChart/`

## ドメイン知識（重要）

- 証券コードはEDINET上5桁、UI上は4桁（末尾0を付けて検索する）
- 会計基準はDEIタグ `AccountingStandardsDEI`（Japan GAAP / US GAAP / IFRS）で判定
- **IFRS企業の連結財務諸表は `jpigp_cor` 名前空間**（日本基準は `jppfs_cor`）。
  現行実装はjppfs_corのみ対応のため、IFRS企業の連結は0で保存される既知課題
- IFRS企業でも**単体財務諸表は日本基準**でタグ付けされる
- 銀行・保険など特定業種は日本基準でも別フォーマット（業種DEIコード bnk/INS等）
- 詳細な実測調査と再設計方針は `docs/zero-base-redesign/`（推奨案）と
  `docs/ifrs-support/`（段階改修案）にある。**XBRLタグを扱う作業の前に必ず
  `docs/zero-base-redesign/01_xbrl_format_research.md` を読むこと**

## 改善バックログ

DX/SEO/AI活用の改善候補は `docs/improvements.md` に整理されている。
