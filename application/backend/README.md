# investee バックエンド（Rails API）

上場企業の有価証券報告書（EDINET）を取り込み、財務3表チャートをGraphQLで返すAPIサーバ。

[financial-statement](https://github.com/shin4488/financial-statement) monorepoの `application/backend` ディレクトリ。設計ドキュメントとdocker-compose定義はリポジトリルート側にある。

## 技術スタック

| 項目 | 内容 |
|---|---|
| 言語・FW | Ruby 3.4.12 / Rails 7.2（`config.api_only = true`） |
| API | GraphQL（graphql-ruby） |
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
| `SERVER_HOST_NAME` / `SECRET_KEY_BASE` | 本番のみ（開発では未設定でよい。用途と生成方法はsampleのコメント参照） |

**git管理されるファイルには設定の「キー名と入手方法」までを書き、実値や実環境の識別子は書かない。**

### 2. 起動

リポジトリルートで `docker compose up` する（DB・Redis込みで一括起動）。
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
  financial_statements/item_catalog.rb # 科目カタログ（唯一の科目一覧。科目ごとの期間・期首の科目・意味）
  edinet/client.rb                     # EDINET API（EDINETとの通信はここだけ）
  xbrl/document.rb                     # XBRLのfact検索プリミティブ
app/models/disclosure/                 # テーブルのモデル
app/services/
  ingestion/                           # 対象確認・形式判定・対応表・抽出・取得式・補正ルール
  use_cases/                           # 入口から呼ぶ処理の手順（日付・docID指定の取込、1有報の取込と点検、書類の逐次実行、一覧の取得）
  charts/                              # 形式ごとのBuilderと部品（チャート構造の組み立て）
  disclosure/report_writer.rb          # 取り込んだ有報の保存（1有報分）
  disclosure/search_query.rb           # 一覧検索（CF符号・証券コード）
  disclosure/reingest_targets.rb       # 再取込タスク（rake ingestion:reingest_*）の対象の検索
app/graphql/
  financial_statement_schema.rb        # スキーマ（複雑度・深さの上限を含む）
  resolvers/financial_reports.rb       # クエリ financialReports
```

設計の意図とXBRLの形式ごとの違いは、[リポジトリ理解ガイド](../../docs/guide/README.md)の[02章](../../docs/guide/02_data_flow.md)・[03章](../../docs/guide/03_system.md)を参照。
**XBRLタグを扱う作業の前に、必ず[タグ対応表](../../docs/guide/05_taxonomy_mapping.md)の該当する表（BS・PL・CF）を読むこと。**

`/graphql` は公開・未認証エンドポイントのため、スキーマに複雑度・深さの上限がある。
フィールドを増やすときは上限に収まるか確認する（`financial_statement_schema.rb`）。

## スキーマ変更時

```bash
bundle exec rake graphql:dump_schema
```

`schema.graphql` を更新してコミットする。フロントの型生成（`npm run compile`）はこれを参照する。
