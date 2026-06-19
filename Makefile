SHELL := /bin/bash

# Shell sources to check/format. Skips git internals and machine-local copies.
SH_FILES := $(shell find . -type f -name '*.sh' \
	-not -path './.git/*' \
	-not -name '*.local.sh' 2>/dev/null)

.PHONY: format lint test install

# Best-effort: format with shfmt when available, otherwise no-op.
format:
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 4 -ci $(SH_FILES); \
	else \
		echo "shfmt not installed; skipping format"; \
	fi

# Best-effort: report shellcheck findings when available, otherwise no-op.
# Informational only — does not gate the commit.
lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S warning $(SH_FILES) || true; \
	else \
		echo "shellcheck not installed; skipping lint"; \
	fi

test:
	@echo "no test suite"

install:
	@./install.sh
