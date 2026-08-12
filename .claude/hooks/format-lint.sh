#!/bin/bash
# Claude CodeのPostToolUse(Write|Edit)フック。編集されたファイルの種類に応じて
# フォーマッタ・リンタを自動実行する。stdinにフック入力JSONが渡される。
# 整形失敗でClaudeの作業を止めない（常にexit 0）
set -u

file_path=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

case "$file_path" in
  *"/application/backend/"*.rb)
    cd "$project_dir/application/backend" &&
      bundle exec rubocop -A --force-exclusion "$file_path" > /dev/null 2>&1
    ;;
  *"/application/frontend/"*.ts | *"/application/frontend/"*.tsx)
    cd "$project_dir/application/frontend" || exit 0
    # eslintの自動修正はコードを挿入することがある（curlyルールの波括弧補完など）ため、
    # eslint --fix を先に実行し、その結果も含めて最後にprettierで整形を確定させる
    npx eslint --fix "$file_path" > /dev/null 2>&1
    npx prettier --write "$file_path" > /dev/null 2>&1
    ;;
esac
exit 0
