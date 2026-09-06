# financial-statement（investee）

上場企業の財務3表（BS/PL/CF）をEDINETからXBRLで取得し、PostgreSQLに保存、Reactでグラフ可視化するWebアプリ。本番: https://investee.info

## リポジトリ構成（monorepo）

```
application/backend    # Rails APIサーバ
application/frontend   # React SPA
web/                   # nginx設定
database/ cache/       # PostgreSQL / Redis のDocker設定
docs/                  # 設計ドキュメント
docker-compose.yml     # 全体起動
```

- CIは `.github/workflows/` の backend-ci / frontend-ci（変更のあった側だけ本体ジョブを実行。変更なし側はskip=必須チェック成功扱い）
- ローカル実行: `docker compose up`（DB初期化は `database/init/`）。バックエンド単体は`application/backend/.ruby-version` 指定のRuby + `bundle exec`で動く（DBはdocker側が必要）

## バックエンド（application/backend）

- Rails + GraphQL（エンドポイント `/graphql`）+ Sidekiq（sidekiq-cronで日次取込）
- 取込は `Ingestion::DailyIngestionService`、参照は `Resolvers::FinancialReports` を入口に調べる。処理のつながりは [03章](docs/guide/03_data_flow.md)、実行日程・依存・設定の現在値は実装・設定を確認する。
- 環境変数は `config/application.yml`（figaro形式・gitignore済みのローカルファイル。シークレットを含むため**このファイルの中身をコミット・ログ・ドキュメントに転記しないこと**）
- EDINET APIはリクエスト過多で403になるため**同期・逐次実行が前提**（並列化しない）
- 公開・未認証エンドポイントのため、スキーマに `max_complexity` / `max_depth` の上限がある（`app/graphql/financial_statement_schema.rb`。フィールドを増やすときは上限に収まるか確認する）

## フロントエンド（application/frontend）

- React/TypeScript。依存と検証コマンドは `package.json`、起動・検証の条件は `application/frontend/README.md` を確認する。
- GraphQLの型生成: `npm run compile`（graphql-codegen。backendのコミット済み`schema.graphql` を参照するためバックエンド起動は不要）
- 主要ページ: `src/features/financialReports/`、汎用チャート: `src/shared/financialCharts/`

## ドメイン知識（重要）

- 証券コードはEDINET上5桁、UI上は4桁（末尾0を付けて検索する）
- 会計基準はDEIタグ `AccountingStandardsDEI`（Japan GAAP / US GAAP / IFRS）で判定
- **IFRSの連結は `jpigp_cor`、日本基準は `jppfs_cor`。IFRS企業でも単体は日本基準。** 詳細タグ義務化前のIFRSには経営指標サマリだけの資料もある。
- 日本基準の銀行・保険は固有の骨格を持つ。他業種のタグは共通形式へのフォールバックを確認する。対応形式・年度条件の一覧は実装とタグ対応表を正とする。米国基準の `unsupported` は説明文を表示する正常系。
- **実装済みアーキテクチャの正は `docs/guide/` の03章（データのつながり: 4層設計・取込・データモデル・チャート生成・描画）と04章（システム構成・信頼性・画面実装）**。旧系統（SecurityReport系）を参照する古い資料ではなく、現行コードとこのガイドを使う
- **XBRLタグを扱う作業の前に`docs/guide/06_taxonomy_mapping.md`の前半にある触る表（BS/PL/CF）の節を読むこと**（全文を読む必要はない。同ファイル後半の「実地調査の記録」は対応表の根拠になった実測なので、対応の理由を確かめたいときだけ開けばよい）

## 検証とPR

- 検証・リリースは [05章](docs/guide/05_development_operations.md)の関連節に従う。backend変更時はローカル専用の実XBRLフィクスチャspecを、コミット・PR前に実行し、pendingなしを確認する。CI成功だけで代替しない。
- frontend変更は同ディレクトリのREADME・scriptsのlint・型・テスト・ビルドを確認する。GraphQL変更時はschemaと生成型を更新・コミットし、クエリ上限への適合も確認する。
- PRのマージはユーザーが行う。backend/frontend同時変更は同じPRにまとめ、デプロイはbackend → frontendの順にする。

## 改善バックログ

SEO・Web/AI活用の改善候補は `docs/improvements.md` に整理されている。

## リポジトリ理解ガイド

ドキュメントの本体は `docs/guide/`（README.mdが目次）。学ぶ章（01〜05: ドメイン知識→仕様→財務データのつながり→システム→開発と運用。技術の基礎説明と設計判断の「なぜ」は03〜04章に織り込まれている）+ 資料（06: タグ対応表と実地調査）の構成。

## 共通エージェント設定

- 共通のGit・PR・検証はpluginのskillsを使う。`make setup` と [READMEの導入手順](README.md#エージェントの導入とhook)を参照する。`.agents/skills` → `.claude/skills` の相対リンクを維持し、ローカルの実体はClaude側で編集する。
- `.claude/hooks/post-edit.sh` のRuby・ESLint・Prettier・型検査を使い、共通Biomeは適用しない。必要なRuby/Bundler・frontend依存を事前に用意する。Claudeの権限設定はCodexに引き継がれない。

## 調査と指示の保守

- `AGENTS.md` は `CLAUDE.md` への相対リンク。本文は一度読み、実体を編集する。
- `rg` は対象ディレクトリから名前・見出し・シンボルを探す。通常は `-g` で依存・成果物・ログ・ロックファイル・生成コードを除外し、依存・生成・型・障害の調査では直接読む。見つからなければ範囲・除外を見直す。
- 必須検証を行い、要点・失敗箇所を報告する。同じ差分・依存・設定・実行条件の結果は再利用する。
- ここは恒久規約・必須条件・主要コマンド・参照先に限る。進捗はチャット・既存Issue/PR、機能・構成・依存・設定等の現在値は元の定義へ。規約・条件・参照先の変更や継続して必要な判断基準の追加時に更新する。
- スキルは説明から選び、該当 `SKILL.md` に従う。一覧・手順は転記せず、このガイドの必須適用条件は守る。
