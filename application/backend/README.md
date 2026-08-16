# investee バックエンド（Rails API）

上場企業の有価証券報告書（EDINET）を取り込み、財務3表チャートをGraphQLで返すAPIサーバ。

**このリポジトリは親リポジトリ [financial-statement](https://github.com/shin4488/financial-statement) の
git submodule**（`application/backend`）。設計ドキュメントとdocker-compose定義は親リポジトリ側にある。

## 技術スタック

| 項目 | 内容 |
|---|---|
| 言語・FW | Ruby 3.4.10 / Rails 7.2（`config.api_only = true`） |
| API | GraphQL（graphql-ruby）。エンドポイントは `POST /graphql` の1本のみ |
| 非同期処理 | Sidekiq + sidekiq-cron（毎日2:00に前日提出分を取込） |
| データストア | PostgreSQL / Redis |

## セットアップ

### 1. 環境変数ファイルを作成

`config/application.yml`（figaro形式）は**gitignore済み**。
`config/application.yml.sample` をコピーして各自の値を設定する:

```bash
cp config/application.yml.sample config/application.yml
```

| キー | 入手方法 |
|---|---|
| `EDINET_API_KEY` | [アカウント登録ページ](https://api.edinet-fsa.go.jp/api/auth/index.aspx?mode=1)で無料発行 |
| `SENTRY_DSN` | 任意（エラー監視を使う場合のみ。未設定なら通知は無効） |
| `POSTGRES_*` / `REDIS_*` | docker利用時はsampleのデフォルト値のままでよい |

**git管理されるファイルには設定の「キー名と入手方法」までを書き、実値や実環境の識別子は書かない。**

### 2. 起動

親リポジトリで `docker compose up` する（DB・Redis込みで一括起動）。
docker外で単体起動する場合は、DBだけdocker側を立てた上で:

```bash
bundle install
```

```bash
bundle exec rails s
```

## データ投入

起動直後のDBは空。EDINETから取り込むrakeタスクは2つ（どちらも冪等・再実行可）:

```bash
bundle exec rake 'ingestion:backfill[2026-06-20,2026-06-30]'
```

```bash
bundle exec rake 'ingestion:documents[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO]'
```

※ EDINET APIはリクエスト過多で403を返すため、取込は**同期・逐次実行が前提**（並列化しない）。

## テスト

```bash
bundle exec rspec
```

外部APIはwebmockで遮断済みのため、テスト実行にEDINET APIキーの実値は不要。

## 主要な構成

```
app/lib/
  financial_statements/item_codes.rb   # 科目コードレジストリ（唯一の科目一覧）
  edinet/client.rb                     # EDINET API（外部I/Oはここだけ）
  xbrl/document.rb                     # XBRLのfact検索プリミティブ
app/models/disclosure/                 # 現行テーブルのモデル
app/services/
  ingestion/                           # 形式判定・Extractor・取込
  charts/                              # ChartBuilder（チャート構造の組み立て）
  disclosure/search_query.rb           # 一覧検索（CF符号・証券コード）
app/graphql/
  financial_statement_schema.rb        # スキーマ（複雑度・深さの上限を含む）
  resolvers/financial_reports.rb       # 現行クエリ financialReports
```

設計意図・XBRLの形式ごとの差異は親リポジトリの `docs/guide/`（03〜04章に設計解説）を参照。
**XBRLタグを扱う作業の前に必ず `docs/guide/07_taxonomy_mapping.md` を読むこと。**

`/graphql` は公開・未認証エンドポイントのため、スキーマに複雑度・深さの上限がある。
フィールドを増やすときは上限に収まるか確認する（`financial_statement_schema.rb`）。

## スキーマ変更時

```bash
bundle exec rake graphql:dump_schema
```

`schema.graphql` を更新してコミットする。フロントの型生成（`npm run compile`）はこれを参照する。
