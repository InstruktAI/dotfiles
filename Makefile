# Native build contract for this dotfiles repo. Targets exist so the tooling
# that drives format/lint/test has something to call; this is a configuration
# repo, so they are intentionally light and never rewrite files. Installing is
# chezmoi's job: see README.md.

.PHONY: format lint test

format:
	@echo "no formatter configured"

lint:
	@echo "no linter configured"

test:
	@echo "no test suite"
