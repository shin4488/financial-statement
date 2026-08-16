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
