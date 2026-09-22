# financial-statement（investee）

EDINETの財務データを可視化する。Rails API: `application/backend/`、React: `application/frontend/`。

## 実装上の注意

- `config/application.yml` は秘密情報を含む。内容をコミット・ログ・文書へ転記しない。
- EDINET APIのアクセス制限を避けるため、同期・逐次実行を維持する。
- `/graphql` は未認証で公開される。変更時は `financial_statement_schema.rb` の `max_complexity` / `max_depth` 上限内で動くか確認する。
- 証券コードはEDINETで5桁、UIで4桁。検索時は末尾に0を追加する。
- 会計基準は `AccountingStandardsDEI` で判断する。IFRS連結は `jpigp_cor`、日本基準は `jppfs_cor`。IFRS企業でも単体は日本基準で、古いIFRS資料にはサマリのみのものがある。
- 銀行・保険の固有形式と業種別フォールバックを維持する。対応形式・年度条件は実装とタグ対応表に従う。米国基準の `unsupported` は説明文を出す正常系。

## 開発・検証

- 起動は `docker compose up`。バックエンドの単体実行は `.ruby-version` 指定のRubyと `bundle exec` を使い、DBはDockerで用意する。
- backend変更時は、コミット・PR前に[ローカル検証](docs/guide/05_development_operations.md#backend変更時のローカル検証)の実XBRLフィクスチャspecをpendingなしで通す。CI成功では代替できない。
- frontend変更時は、同README・`package.json` に従いlint・型・テスト・ビルドを確認する。
- GraphQL変更時はschemaと生成型を更新・コミットする。
- CIのskipを実行済みと扱わない。
- backendとfrontendの両方を変更する場合は同じPRにまとめる。マージはユーザーが行い、デプロイはbackend → frontendの順。
- `.claude/hooks/post-edit.sh` はRuby・ESLint・Prettier・型検査を行う。編集前に対象側の依存を用意し、共通Biomeは適用しない。

## 作業の進め方

- `.agents/skills` → `.claude/skills` は相対リンク。本文を重複して読まず、リンク先を編集する。
- 対象箇所から調べ、必要な資料・skillsだけを読む。
- 不明点は質問して解消してから、その判断に依存する作業に進む。すでに決まっている事項は再確認しない。
- 文書の言語を保ち、日本語は日本人に、英語は英語圏の読者に自然に伝わる表現にする。
- 必須検証は適用条件に従って実行し、同じ差分・依存・設定・実行条件で得た結果は再利用する。問題を修正し、結果と未確認の範囲を簡潔に報告する。
- このファイルには継続して必要な規約だけを残し、進捗・設定値・他の資料やskillsの手順を複製しない。
