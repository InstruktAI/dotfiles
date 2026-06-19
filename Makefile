# Native build contract for this dotfiles repo. Targets exist so the tooling
# that drives format/lint/test/install has something to call; this is a
# configuration repo, so they are intentionally light and never rewrite files.

.PHONY: format lint test install

format:
	@echo "no formatter configured"

lint:
	@echo "no linter configured"

test:
	@echo "no test suite"

install:
	@./install.sh
