---
name: pr
description: ブランチ作成・コミット・PR作成・マージ後の反映の運用手順。PRを作るとき・マージ後の後始末のときに使用する。
---

# PR運用

単一リポジトリ（monorepo）。backend/frontend/docsどこを変更しても、コミット・PRは1本でよい。

## 手順

```bash
git checkout main && git pull
git checkout -b <feature/fix/choreブランチ名>
# 変更 → 意味ごとにコミット → push → gh pr create
```

- コミットは意味ごとに分ける。メッセージはprefix(`add:` `update:` `change:` `fix:`)+末尾に
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- PR本文の末尾は `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- backendとfrontendの両方に変更がある場合も1本のPRでよいが、
  **デプロイはbackend → frontendの順**（フロントが新APIに依存し得るため。/deploy 参照）
- マージはユーザーが行う

## コミット前の機密情報チェック

作業ツリー全体ではなく「実際にコミットされるもの（ステージ済みの内容）」を確認してからコミットする:

```bash
git status --short   # gitignore対象（config/application.yml等）が誤ってstageされていないか
git diff --cached | grep -niE "api[_-]?key|secret|password|token|dsn|private key|BEGIN (RSA|OPENSSH)"
```

- 実値を書いてはいけないもの: APIキー・DSN・パスワード・トークン類、本番のホスト名/IP/接続情報
  （git管理されるファイルには「項目名と入手方法」まで。docs/guide/06章の規約）
- grepの一致=即NGではない。変数名・設定キー名・sampleのプレースホルダは問題なく、**実値かどうか**で判断する
- 機密を含めてコミットしてしまったら: push前ならcommitを作り直す。push済みなら履歴から消えないため、
  該当キーのローテーション（無効化・再発行）が必要

## コミット前のspec実行（backend変更時）

実XBRLフィクスチャを入力にするスペックは、フィクスチャがgit管理外（ローカル限定）のため
**CIではskip（pending扱い）されて緑になる**。この範囲の保証はローカル実行だけが担うので、
バックエンドに変更があるときはコミット・PR作成の前に該当specをローカルで実行する
（それ以外のspecはCIが全件実行するため、ローカルで回すのはこの範囲だけでよい）:

```bash
docker compose exec appserver bash -c 'cd /home/app/financialStatement && bundle exec rspec $(grep -rl xbrl_fixture spec --include="*_spec.rb")'
```

- 対象ファイルはフィクスチャ利用の目印（`xbrl_fixture` ヘルパ呼び出し）をgrepで拾う。
  固定リストにしない理由: フィクスチャを使うspecが増えたときにここを直し忘れても漏れないようにする
- 結果は `0 failures` かつ **pendingなし**まで確認する。`N pending` が出たらフィクスチャ未取得
  （`application/backend/spec/fixtures/xbrl/README.md` の手順で取得して再実行）

## CI

- `.github/workflows/` の backend-ci / frontend-ci が、変更のあった側だけ本体ジョブを
  実行する（backendは `application/backend/**`、frontendは `application/frontend/**` +
  `application/backend/schema.graphql`。判定はワークフロー内のchangesジョブが行う）
- mainの必須status checkは `backend` / `frontend`。変更がない側のジョブはskipされ
  **成功扱い**になるため、docs等のみのPRでもマージはブロックされない

## マージ後の後始末

```bash
git checkout main && git pull
```
