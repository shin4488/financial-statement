#!/usr/bin/env bash
# Claude / Codex 共通。残った指摘は返すが、編集後の処理はブロックしない。
# 共通プラグインがリポジトリルートとファイル一覧を確定するため、イベントJSONは再解析しない。
project_dir=$PWD
files=("$@")
backend=()
frontend=()
for file in "${files[@]}"; do
  case "$file" in
    "$project_dir"/application/backend/*.rb | "$project_dir"/application/backend/*.rake | \
    "$project_dir"/application/backend/Gemfile | "$project_dir"/application/backend/Rakefile | \
    "$project_dir"/application/backend/config.ru) backend+=("$file") ;;
    "$project_dir"/application/frontend/*.ts | "$project_dir"/application/frontend/*.tsx)
      frontend+=("$file") ;;
  esac
done

# 複数ファイルをまとめて渡し、プロジェクト全体の型検査を繰り返さない。
out=$({
  if [ "${#backend[@]}" -gt 0 ]; then
    (
      cd "$project_dir/application/backend" || exit
      bundle exec rubocop -A --force-exclusion --format emacs "${backend[@]}" 2>&1 |
        grep -v '\[Corrected\]'
    )
  fi
  if [ "${#frontend[@]}" -gt 0 ]; then
    (
      cd "$project_dir/application/frontend" || exit
      # ESLint の修正後に Prettier で整える。未導入ツールの自動取得はしない。
      node_modules/.bin/eslint --fix "${frontend[@]}"
      node_modules/.bin/prettier --write "${frontend[@]}" >/dev/null
      node_modules/.bin/tsc --noEmit
    )
  fi
} 2>&1)

if [ -n "$out" ]; then
  # 編集済みのコードは残し、診断を追加コンテキストとして返す既存の運用を維持する。
  jq -n --arg ctx "format-lint hook: 自動修正後も残った指摘（CIで失敗し得るため対処すること）
$out" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
fi
exit 0
