# financial-statement（investee）

EDINETのXBRLを取り込み、財務3表をPostgreSQLに保存してReactで可視化する。Rails APIは `application/backend/`、Reactは `application/frontend/`。本番: https://investee.info

## 調査の入口

| 作業 | 参照先 |
| --- | --- |
| 取込・参照・チャートの流れ | `Ingestion::DailyIngestionService`、`Resolvers::FinancialReports`、[03章](docs/guide/03_data_flow.md)の関連節 |
| 構成・信頼性・画面設計 | [04章](docs/guide/04_system.md)の関連節 |
| XBRLタグの変更 | [06章](docs/guide/06_taxonomy_mapping.md)の対象表（BS/PL/CF）の節を先に読む。後半の調査記録は根拠を調べる場合だけ |
| 開発・検証・リリース | [05章](docs/guide/05_development_operations.md)の関連節 |
| SEO等の改善候補 | [改善バックログ](docs/improvements.md) |

現行コードと `docs/guide/` を正とし、旧SecurityReport系の資料を実装の根拠にしない。

## バックエンドの条件

- 起動は `docker compose up`。単体実行は `.ruby-version` 指定のRubyと `bundle exec` を使い、DBはDockerで用意する。初期化定義は `database/init/`。
- `config/application.yml` はgit管理外の秘密情報を含む。内容をコミット・ログ・文書へ転記しない。
- EDINET APIはリクエスト過多で403になるため同期・逐次実行を維持する。
- `/graphql` は未認証で公開される。フィールド追加時は `financial_statement_schema.rb` の `max_complexity` / `max_depth` 上限内で動くか確認する。
- 証券コードはEDINET上5桁、UI上4桁（検索では末尾0を追加）。会計基準は `AccountingStandardsDEI` で判断する。IFRS連結は `jpigp_cor`、日本基準は `jppfs_cor`。IFRS企業でも単体は日本基準で、古いIFRS資料にはサマリのみのものがある。
- 銀行・保険の固有形式と他業種のフォールバックを維持する。対応形式・年度条件は実装とタグ対応表を正とする。米国基準の `unsupported` は説明文を出す正常系。

## フロントエンドと検証

- フロントのコマンドと条件は `application/frontend/package.json` と同READMEに従う。主要画面は `src/features/financialReports/`、共有チャートは `src/shared/financialCharts/`。
- GraphQL変更時はschemaと生成型を更新・コミットする。`npm run compile` はコミット済み `schema.graphql` を使うため、バックエンド起動は不要。
- backend変更時は、コミット・PR前に05章のローカル専用実XBRLフィクスチャspecを実行し、pendingなしを確認する。CI成功では代替できない。frontend変更時は同READMEのlint・型・テスト・ビルドを確認する。
- CIは変更側だけ本体ジョブを実行する。変更なし側のskipを実行済みと扱わない。両側を変える場合は同じPRにまとめる。マージはユーザーが行い、デプロイはbackend → frontendの順。

## 共有設定

- pluginの導入は [Makefile](Makefile) の `make setup`。必要なGit・PR・検証のskillだけを使う。`.agents/skills` は `.claude/skills` への相対リンクで、Claude側を編集する。
- `.claude/hooks/post-edit.sh` はRuby・ESLint・Prettier・型検査を行う。共通Biomeは適用しない。対象コードを編集するときにRuby/Bundler・frontend依存を用意する。Claudeの権限設定はCodexに引き継がれない。

## 作業の進め方

- `AGENTS.md` はこのファイルへの相対リンク。共通の本文は一度だけ読み、`CLAUDE.md` を編集する。
- 対象のファイル・見出し・シンボルから調べ、必要な場合だけ範囲を広げる。資料やskillsは作業に該当するものを読む。
- 不明点は質問して解消してから、その判断に依存する作業に進む。すでに決まっている事項は再確認しない。
- 文書の言語を保ち、日本語は日本人に、英語は英語圏の読者に自然に伝わる表現にする。
- 必須検証は適用条件に従って実行し、同じ差分・依存・設定・実行条件で得た結果は再利用する。問題を修正し、結果と未確認の範囲を簡潔に報告する。
- このガイドには継続して必要な規約と参照先を残す。進捗や設定値、他の資料・skillsの手順は複製しない。
