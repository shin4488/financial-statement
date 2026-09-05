# 導入済みのCLIにだけ共通AIプラグインを登録する。ユーザー単位なので他リポジトリでも使える。
.PHONY: setup

setup:
	@if command -v claude >/dev/null 2>&1; then \
		claude plugin marketplace add shin4488/agent-plugins --scope user && \
		claude plugin install agent-plugins@agent-plugins --scope user; \
	else \
		printf '%s\n' 'Claude Code is not installed; skipping plugin setup.'; \
	fi
	@if command -v codex >/dev/null 2>&1; then \
		codex plugin marketplace add shin4488/agent-plugins && \
		codex plugin add agent-plugins@agent-plugins; \
	else \
		printf '%s\n' 'Codex is not installed; skipping plugin setup.'; \
	fi
