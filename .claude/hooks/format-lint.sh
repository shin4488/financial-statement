#!/bin/bash
# Claude CodeのPostToolUse(Write|Edit)フック。編集されたファイルの種類に応じてフォーマッタ・リンタを自動実行し、
# 自動修正しきれなかった指摘（構文エラー・型エラーなど）をClaudeに返す。対象と使うツールはCI（.github/workflows/*-ci.yml）と揃える。
# 整形失敗や指摘の有無でClaudeの作業を止めない（常にexit 0）
file_path=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

case "$file_path" in
  # rubocopはGemfile等の拡張子なしファイルもCIで検査するため対象を揃える。-Aで自動修正し、修正済み([Corrected])以外の指摘を残す。
  # 既定の形式は指摘ゼロでも進捗・集計行を出して空判定できないため、指摘1件=1行で他に何も出さないemacs形式にする
  *"/application/backend/"*.rb | *"/application/backend/"*.rake | *"/application/backend/"Gemfile | *"/application/backend/"Rakefile | *"/application/backend/"config.ru)
    cd "$project_dir/application/backend" || exit 0
    out=$(bundle exec rubocop -A --force-exclusion --format emacs "$file_path" | grep -v '\[Corrected\]')
    ;;
  # eslintの自動修正はコードを挿入することがある（curlyルールの波括弧補完など）ため、eslint --fix → prettier の順で整形を確定させる。
  # 型検査は1ファイル単位ではできないためCIと同じくプロジェクト全体にかける
  *"/application/frontend/"*.ts | *"/application/frontend/"*.tsx)
    cd "$project_dir/application/frontend" || exit 0
    out=$(npx eslint --fix "$file_path"; npx prettier --write "$file_path" > /dev/null; npx tsc --noEmit)
    ;;
  *) exit 0 ;;
esac

# 残った指摘はadditionalContextでClaudeに渡す
[ -n "$out" ] && jq -n --arg ctx "format-lint hook: 自動修正後も残った指摘（CIで失敗し得るため対処すること）"$'\n'"$out" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
