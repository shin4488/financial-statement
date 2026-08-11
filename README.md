# financial-statement（investee）

上場企業の財務三表（貸借対照表・損益計算書・キャッシュフロー計算書）を可視化するWebアプリ。
EDINET（金融庁の開示システム）から有価証券報告書のXBRLを日次で取得・パースしてPostgreSQLに保存し、
Reactの画面で積み上げグラフ・ウォーターフォールグラフとして表示する。

本番環境: https://investee.info

## 主な機能

- 上場企業の財務三表のグラフ表示（連結優先。連結がない企業は単体）
- 証券コード（4桁）による企業検索
- キャッシュフローのパターン（営業/投資/財務CFの正負の組合せ）による絞り込み
- EDINETに提出された有報の日次自動取込（毎日2:00にバッチ実行）

## リポジトリ構成

```
financial-statement/            # このリポジトリ（親）
├── application/
│   ├── backend/                # Rails APIサーバ（★別リポジトリのgit submodule）
│   └── frontend/               # React SPA（★別リポジトリのgit submodule）
├── web/                        # nginx（リバースプロキシ）の設定
├── database/                   # PostgreSQLのDockerfile・初期化SQL
├── cache/                      # RedisのDockerfile（Sidekiqのジョブキュー用）
├── docs/                       # 設計ドキュメント
├── docker-compose.yml          # 開発環境の全体起動
└── CLAUDE.md                   # AIエージェント向けのリポジトリコンテキスト
```

**submoduleに注意**: `application/backend` と `application/frontend` は別リポジトリ。
中のファイルを変更したら「各リポジトリでコミット→親リポジトリでハッシュ更新コミット」の2段階が必要。

## 技術スタック

| 層 | 技術 |
|---|---|
| フロントエンド | React (CRA + craco) / TypeScript / Apollo Client / Redux Toolkit / MUI / recharts |
| バックエンド | Ruby 3.2.2 / Rails 7 / GraphQL (graphql-ruby) / Sidekiq + sidekiq-cron |
| データストア | PostgreSQL 12 / Redis |
| インフラ（開発） | Docker Compose + nginx |
| 外部API | EDINET API v2（有報一覧・XBRL取得） |

## セットアップ

### 前提

- Docker / Docker Compose
- EDINET APIキー（[EDINET API](https://api.edinet-fsa.go.jp/)のページで無料発行できる）

### 手順

```bash
# 1. submoduleごとclone
git clone --recursive https://github.com/shin4488/financial-statement.git
cd financial-statement

# 2. バックエンドの環境変数ファイルを作成（figaro形式・gitignore済み）
#    application/backend/config/application.yml に以下の項目を設定する:
#      EDINET_API_KEY: EDINET APIのページで発行したキー
#      SENTRY_DSN:     任意（エラー監視を使う場合のみ。空文字でよい）
#    ※このファイルはシークレットを含むため、絶対にコミットしないこと

# 3. 全サービス起動（初回はイメージビルド・bundle install・npm installが走るため時間がかかる）
docker compose up
```

DB（`financial_statement_development`）は初回起動時に `database/init/1.0.0.sql` で作成され、
マイグレーションはappserverコンテナの起動スクリプト内で自動実行される。
DB接続情報などの環境変数は各Dockerfileに定義済みで、手動設定は不要。

### 起動後のURL

| URL | 内容 |
|---|---|
| http://localhost:10000 | フロントエンド（nginx経由） |
| http://localhost:10000/api/... | バックエンドAPI（nginx経由。`/api` が appserver にプロキシされる） |
| http://localhost:20000/graphql | バックエンドAPI直接（GraphQLエンドポイント） |

### データ投入

起動直後のDBは空。EDINETから有報を取り込むには（EDINET APIキーが必要）:

```bash
# 方法1: 日付範囲を指定して取込（その期間に提出された全上場企業の有報）
docker compose exec appserver bundle exec rake 'ingestion:backfill[2026-06-20,2026-06-30]'
```

```bash
# 方法2: EDINETの書類管理番号（docID）を指定して取込
# 例は各会計基準・業種の検証用6社（詳細: docs/guide/12_taxonomy_mapping.md）
docker compose exec appserver bundle exec rake 'ingestion:documents[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO]'
```

※ EDINET APIはリクエスト過多で403を返すため、取込は同期・逐次実行が前提（並列化しないこと）。
※ 6月は有報提出のピークのため、方法1を6月の日付で実行すると1日あたり数百件の取込になる。

## 開発

### バックエンド単体で動かす（docker外）

rbenv等でRuby 3.2.2を入れて:

```bash
cd application/backend
bundle install
bundle exec rails s   # DBはdocker側のdatabaseコンテナを起動しておく必要がある
```

### GraphQLの型生成（フロントエンド）

バックエンドのスキーマ変更後、フロントの型を再生成する（バックエンド起動が必要）:

```bash
cd application/frontend
npm run compile        # graphql-codegen。src/__generated__/ が更新される
```

### 日次バッチ

`sidekiq-cron` により毎日2:00に前日提出分の有報を自動取込する
（`application/backend/config/sidekiq-cron.yml` / `DailyIngestionJob`）。
Sidekiqはappserverコンテナの起動スクリプト内で一緒に立ち上がる。

## ドキュメント

| パス | 内容 |
|---|---|
| [docs/guide/](docs/guide/README.md) | **ドキュメントの本体**。前提知識ゼロから読める入門〜運用（01〜07）+ 設計判断の深掘り（08〜11）+ タグ対応表・実測データなどの資料（12〜13） |
| [docs/improvements.md](docs/improvements.md) | DX / SEO / AI活用の改善バックログ（作業手順つき） |
| [CLAUDE.md](CLAUDE.md) | AIエージェント向けコンテキスト（ドメイン知識・既知課題の要約） |

## 対応状況と既知の課題

表示できる形式は「会計基準 × 表示様式」で決まる（詳細は
[docs/guide/02_product.md](docs/guide/02_product.md)）。

| 形式 | 対象 | 状態 |
|---|---|---|
| `jgaap_general` | 日本基準・一般事業会社 | 対応済み |
| `jgaap_bank` | 日本基準・銀行 | 対応済み |
| `ifrs_classified` / `ifrs_liquidity` | IFRS（連結） | 対応済み |
| `unsupported` | 米国基準・日本基準の保険等 | チャートの代わりに説明文を表示（正常系） |

- **米国基準・日本基準の保険業などは未対応**: 上記 `unsupported` として扱われ、
  グラフの代わりにその旨が表示される。追加はExtractor・Builderのファイル追加のみで済む
  （マイグレーション不要。手順は [docs/guide/10_ingestion.md](docs/guide/10_ingestion.md)）
- **旧系統（SecurityReport系）は`security_reports`テーブルのみ凍結保管**: コードは
  すべて削除済み。凍結データの扱いは
  [docs/guide/13_legacy_cleanup.md](docs/guide/13_legacy_cleanup.md)
- その他は [docs/improvements.md](docs/improvements.md) を参照
