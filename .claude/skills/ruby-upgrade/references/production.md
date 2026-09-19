# Ruby更新の本番反映

本番反映を依頼された場合に読む。更新方針への合意だけで本番反映や旧版の削除を始めない。git管理外の `/deploy` skillが利用できなければ、接続先・事前確認・実行担当をユーザーに確認し、推測で操作しない。`HOST`・`SERVER_DIR` の実値はこの文書に保存しない。

## 1. 新Rubyを導入する

新Rubyのインストールをrsyncより先に行う。転送を先にすると、`.ruby-version` とGemfileが未導入のRubyを参照して起動できなくなる。

```bash
ssh -o BatchMode=yes "$HOST" "bash -ic 'git -C ~/.rbenv/plugins/ruby-build pull --ff-only && rbenv install <新版>'"
```

稼働中のプロセスは旧Rubyを使い続ける。`rbenv global` も旧版のままでよく、アプリはディレクトリの `.ruby-version` を優先する。

Sidekiqのsystemdユニットは `~/.rbenv/shims/bundle` とWorkingDirectoryの `.ruby-version` に追従する構成なので、通常は変更不要。`start.sh` から対象ユニット名を確認し、`systemctl cat <ユニット名>` で実際の設定を確かめる。

## 2. 転送してgemを再ビルドする

`/deploy` の事前確認を済ませてから実行する。

```bash
bash application/backend/deploy.sh
ssh -o BatchMode=yes "$HOST" "cd $SERVER_DIR && bash -ic 'bundle install --path vendor/bundle'"
```

ネイティブ拡張は `vendor/bundle/ruby/<新ABI>/` に入り、旧ABIと共存する。サーバの `.bundle/config` には `BUNDLE_PATH: vendor/bundle` が保存されていることを確認する。

## 3. ユーザーが再起動する

gemの再ビルドが完了した後、ユーザーの対話端末で `start.sh` を実行してもらう。Sidekiq → Pumaの順に再起動し、sudoが必要。gemの準備前に実行すると、先頭のSidekiq再起動が失敗する。

`tmp/pids/server.pid` が消えていると旧Pumaが残り、新Pumaがポート競合で起動できないことがある。プロセスが存在するだけで反映成功としない。

## 4. 稼働状態を確認する

`/deploy` の反映確認に加え、対象サービスのPumaを `pgrep -af puma` で特定し、`readlink /proc/<PID>/exe` が新Rubyを指すことを確認する。最初に見つかったPIDを無条件に使わない。

旧Pumaが残った場合は、対象プロセスを確認して停止し、`ss -tln` でポート解放を確認してから次のコマンドで起動し直す。

```bash
bundle exec ./bin/rails s -d -e production -p <ポート>
```

本番のログインシェルで実行し、正しいrbenv環境を使う。直ちに起動し直すとポート競合を繰り返すことがある。

Sidekiqの稼働とcron登録も確認する。

```bash
ssh -o BatchMode=yes "$HOST" "systemctl is-active <sidekiqユニット名>"
ssh -o BatchMode=yes "$HOST" "cd $SERVER_DIR && bash -ic 'RAILS_ENV=production bundle exec rails runner \"puts Sidekiq::Cron::Job.all.map { |j| j.name + %q( ) + j.cron }\"'"
```

翌朝の日次取込（DailyIngestionJob）も確認する。タグ・Releaseの作成まで依頼されている場合は、反映確認後に共通 `release` skillを使う。

## ロールバックと後始末

旧Rubyと `vendor/bundle/ruby/<旧ABI>` はロールバック用に残す。戻す場合は旧コミットを転送して `.ruby-version` を戻し、ユーザーが `start.sh` を実行する。

数日安定してから、旧Ruby・旧ABIの削除と `rbenv global` の更新をユーザーに確認する。ローカルMacのrbenvを更新する場合も、別環境の変更として確認する。
