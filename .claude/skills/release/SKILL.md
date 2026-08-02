---
name: release
description: GitHub上でtagとreleaseを作成する手順。命名(release-X.Y.Z)・対象リポジトリの決め方・リリースノートの体裁。「リリースして」「タグを切って」で使用する。
---

# リリース作成（tag + GitHub Release）

## 対象ブランチ

**常に各リポジトリの `main` の先端コミット**にタグを付ける（`gh release create` の `--target main` で明示）。
featureブランチや過去のコミットへのタグ付けはしない。リリースしたい変更は先にPRでmainへマージしてから行う。

## 命名規則（既存踏襲）

- タグ名 = リリース名 = **`release-X.Y.Z`**（例: `release-1.1.11`, `release-1.2.1`）
- 版番号の決め方（作成前に**必ずユーザーへ提案して確認**する）:
  - 機能追加を含む → Yを+1し、Zは1から（前例: 1.1.11 → 1.2.1）
  - 修正のみ → Zを+1
- `release-1.1.11.submodules` のような接尾辞付きは構成変更時の過去の特例。通常は使わない

## 対象リポジトリの決め方

- **親リポジトリは毎回作成**する
- **backend / frontend は「前回タグ以降にコミットがあるリポジトリだけ」作成**する
  （前例: release-1.2.1 は親+backendのみ。frontendは変更がなかったため作成せず）
- 同一リリースは全対象リポジトリで**同じタグ名・同じリリースノート**を使う（前例踏襲）

## 手順

### 1. 事前確認

```bash
# 3リポジトリともmain最新・作業ツリークリーンであること
cd application/backend && git checkout main && git pull && cd ../frontend && git checkout main && git pull && cd ../.. && git checkout main && git pull && git status --short
```

リリース対象の変更が本番反映済みか（deploy skill参照）も確認するとよい。

### 2. 前回タグと変更点の収集

```bash
# 各リポジトリで実行（親・backend・frontend）
git fetch --tags && git describe --tags --abbrev=0 main   # 前回タグ
git log $(git describe --tags --abbrev=0 main)..main --oneline   # それ以降の変更
```

- backend/frontendは上記のログが**0件ならそのリポジトリはリリース対象外**
- リリースノートは変更ログ・マージ済みPRタイトルから**簡潔な英語の箇条書き**に要約する
  （前例: `- start to use Sentry for error notification and trace logic performance`）。
  機密（ホスト名・キー・実値）は書かない。リリースは公開情報

### 3. 版番号をユーザーに確認

変更内容の要約と「release-X.Y.Z にするか」を提示し、確認を得てから作成する。

### 4. 作成（対象submodule → 親の順）

親のポインタが指すコミットに先にタグが付いている状態にするため、submodule側から作成する:

```bash
# 対象のsubmoduleごと（リポジトリを--repoで指定。tagも同時に作成される）
gh release create release-X.Y.Z --repo shin4488/financial-statement-backend --target main --title "release-X.Y.Z" --notes "- 変更点の箇条書き"
```

```bash
# 親（親リポジトリ直下で）
gh release create release-X.Y.Z --target main --title "release-X.Y.Z" --notes "- 変更点の箇条書き"
```

### 5. 確認

```bash
gh release view release-X.Y.Z && gh release view release-X.Y.Z --repo shin4488/financial-statement-backend
```

## 注意

- 作成済みタグは動かさない。作り直す場合は `gh release delete release-X.Y.Z --cleanup-tag` で
  release・tagを両方消してから再作成する（公開後の削除は履歴に残るため、作成前の内容確認を優先）
- リリース作成は公開操作。実行前にノート本文をユーザーに見せて確認を得る
