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

- `.github/workflows/` の backend-ci / frontend-ci が `paths:` フィルタで
  変更のあった側だけ実行される（backendは `application/backend/**`、
  frontendは `application/frontend/**` + `application/backend/schema.graphql`）
- mainの必須status checkは `backend` / `frontend`。docs等のみのPRではどちらも
  実行されず「Expected」のまま残るが、管理者はそのままマージできる
  （ブランチ保護のenforce_adminsが無効のため）

## マージ後の後始末

```bash
git checkout main && git pull
```
