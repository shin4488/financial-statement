---
name: ruby-upgrade
description: Rubyの更新・EOL対応、またはRailsの更新時に、互換性とDockerでの動作を検証する。
---

# Ruby・Railsを更新する

対象バージョンと依頼範囲を確定し、ローカル検証まで進める。本番反映は別工程として扱う。

## バージョンと互換性

- Ruby・Railsの公式サポート情報とアップグレードガイドで、EOL・最新パッチ・対応範囲を確認する。`Gemfile`・lockfile・`.ruby-version` を現在値とし、古い対応表を前提にしない。
- 現行Railsが目標Rubyに未対応なら、Railsを先に別ブランチ・別PR・別デプロイで更新する。選定理由を示してユーザーと合意し、合意済みの内容は再確認しない。
- Railsは1マイナーずつ検証する。`config.load_defaults` はcookie/session、cache、ActiveJob引数、生SQLの型変換への影響を確認してから変更する。YJITを有効にする場合は本番VPSのメモリ余力を確認し、未確認なら `config.yjit = false` を維持する。
- Rails更新時は `rails zeitwerk:check` と `CI=1 bundle exec rspec` でeager loadも検証する。`db/schema.rb` のバージョン差分を含める。

## Dockerで更新・検証する

ローカルMacにRubyを追加せず、`application/backend` の `.ruby-version`・`Gemfile`・`Dockerfile`・`Gemfile.lock` と、関連READMEの記載をそろえる。旧版の検索は設定・文書に絞り、`tmp/` の過去ログは対象にしない。

```bash
docker compose build appserver
docker compose up -d --force-recreate appserver
docker compose exec appserver ruby -v
docker compose run --rm appserver bash -c 'BUNDLE_PATH=vendor/bundle bundle update --ruby'
```

- `restart` は旧イメージを使うため、再ビルド後はコンテナを作り直す。DB等は必要に応じてComposeで起動する。
- Rubyだけを更新する場合、lockfileの差分は `RUBY VERSION` と `BUNDLED WITH` に限定し、gemの解決が変わっていないことを確認する。
- `BUNDLED WITH` はDockerと本番rbenvの同梱Bundlerを確認して合わせる。`bundle update --bundler` で無条件に最新化しない。現行の `deploy.sh`・`start.sh`・`docker_setup.sh` は `--path` の設定記憶に依存するため、そのままBundler 4にしない。
- 公式RubyイメージのBundler設定は単発コンテナ間で残らない。単発コマンドごとに `BUNDLE_PATH=vendor/bundle` または対応する `--path vendor/bundle` を指定する。
- PR前にRails/Puma起動、GraphQLの実データ応答、nginx経由（:10000）の画面200、Sidekiq起動と `daily_ingestion_job` 登録、RSpec、RuboCopを確認する。ルートガイドの実XBRLフィクスチャ検証も必要。

## PRと本番反映

PR作成を依頼された場合は共通 `create-pr` skillを使い、選定理由・検証結果・Bundlerの制約を記載する。

本番反映を行う場合だけ [本番手順](references/production.md) を読む。新Rubyの導入、転送、gemの再ビルド、ユーザーによる再起動、稼働Rubyの確認の順序を守る。旧版はロールバック用に残し、削除はユーザーへの確認後に行う。
