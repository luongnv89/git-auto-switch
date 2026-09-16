.PHONY: all lint test test-docker clean check-deps help install coverage version-check security-scan security-setup

SHELL := /bin/bash
SCRIPTS := git-auto-switch install-curl.sh lib/bootstrap.sh $(wildcard lib/**/*.sh) $(wildcard scripts/*.sh)

# Pinned bats version (F-TEST-004): local installs, CI, and the
# bats/bats image used by `make test-docker` must all agree on this.
BATS_VERSION ?= 1.14.0

# Pinned gitleaks version: the local `security-scan` docker fallback and
# the CI security job must agree on this.
GITLEAKS_VERSION ?= 8.30.1

all: lint test version-check

## Linting
lint:
	@echo "Running ShellCheck..."
	@shellcheck --source-path=lib $(SCRIPTS)
	@echo "ShellCheck passed!"

## Testing
test:
	@echo "Running tests..."
	@bats test/

## Version single-source check (F-CLEAN-003): fails when any shipped
## version copy diverges from VERSION. `scripts/check-version.sh --sync`
## rewrites the copies from VERSION at release time.
version-check:
	@echo "Checking version sources against VERSION..."
	@bash scripts/check-version.sh

## Testing without a local bats install (containerized fallback).
## Uses the pinned bats/bats image and adds git, jq, and an ssh client
## inside the container, so this works from a clean checkout with only
## Docker installed.
test-docker:
	@echo "Running tests in container (bats/bats:$(BATS_VERSION))..."
	@docker run --rm --entrypoint sh -v "$(CURDIR):/code" -w /code bats/bats:$(BATS_VERSION) -c "apk add --no-cache git jq openssh-client >/dev/null && git config --global --add safe.directory /code && bats test/"

## Check dependencies
check-deps:
	@echo "Checking dependencies (pinned: bats-core v$(BATS_VERSION))..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found. Install with: brew install shellcheck (macOS) or: sudo apt-get install shellcheck (Debian/Ubuntu)"; exit 1; }
	@command -v bats >/dev/null 2>&1 || { echo "bats not found (pinned: bats-core v$(BATS_VERSION)). Install with: brew install bats-core (macOS) or: sudo apt-get install bats (Debian/Ubuntu), or from source: git clone --branch v$(BATS_VERSION) --depth 1 https://github.com/bats-core/bats-core.git. No install? Run the suite containerized instead: make test-docker"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Install with: brew install jq (macOS) or: sudo apt-get install jq (Debian/Ubuntu)"; exit 1; }
	@echo "All dependencies installed!"

## Install to ~/.local/bin (user-local, no sudo needed)
install:
	@echo "Installing git-auto-switch to ~/.local/bin..."
	@mkdir -p ~/.local/bin
	@ln -sf "$(CURDIR)/git-auto-switch" ~/.local/bin/git-auto-switch
	@ln -sf "$(CURDIR)/git-auto-switch" ~/.local/bin/gas
	@echo "Installed! Ensure ~/.local/bin is in your PATH"
	@echo "Run 'git-auto-switch --help' or 'gas --help'"

## Install to /usr/local/bin (requires sudo)
install-global:
	@echo "Installing git-auto-switch to /usr/local/bin..."
	@sudo ln -sf "$(CURDIR)/git-auto-switch" /usr/local/bin/git-auto-switch
	@sudo ln -sf "$(CURDIR)/git-auto-switch" /usr/local/bin/gas
	@echo "Installed! Run 'git-auto-switch --help' or 'gas --help'"

## Uninstall from ~/.local/bin
uninstall:
	@echo "Uninstalling git-auto-switch from ~/.local/bin..."
	@rm -f ~/.local/bin/git-auto-switch ~/.local/bin/gas
	@echo "Uninstalled!"

## Uninstall from /usr/local/bin (requires sudo)
uninstall-global:
	@echo "Uninstalling git-auto-switch from /usr/local/bin..."
	@sudo rm -f /usr/local/bin/git-auto-switch /usr/local/bin/gas
	@echo "Uninstalled!"

## Secret scanning: gitleaks over the full git history. Prefers a local
## gitleaks install; falls back to the pinned docker image (like
## test-docker). Exits non-zero on any finding or when neither is
## available — a security gate must fail closed, never silently skip.
security-scan:
	@echo "Running secret scan (gitleaks)..."
	@if command -v gitleaks >/dev/null 2>&1; then \
		gitleaks git --redact .; \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm --entrypoint sh -v "$(CURDIR):/repo" "zricethezav/gitleaks:v$(GITLEAKS_VERSION)" -c "git config --global --add safe.directory /repo && gitleaks git --redact /repo"; \
	else \
		echo "gitleaks not found. Install with: brew install gitleaks (macOS) or see https://github.com/gitleaks/gitleaks#installing"; \
		exit 1; \
	fi

## Alias for the recorded issue-#32 verify command.
security-setup: security-scan

## Cleanup
clean:
	@rm -rf test/tmp .bats-run-* .coverage coverage.xml coverage

## Coverage: Python via pytest --cov (always); bash via kcov when installed.
## Graceful skip when kcov is missing so `make coverage` stays green on a
## clean checkout without kcov (F-TEST-002).
coverage:
	@echo "Python coverage (pytest --cov)..."
	@python3 -m pytest --cov=git_auto_switch --cov-report=term-missing tests/
	@if command -v kcov >/dev/null 2>&1; then \
		echo "Bash coverage (kcov)..."; \
		mkdir -p coverage/kcov; \
		kcov --include-path=lib,git-auto-switch coverage/kcov bats test/; \
	else \
		echo "kcov not installed - skipping bash coverage (exit 0)."; \
		echo "Install with: sudo apt-get install kcov (Debian/Ubuntu) or: brew install kcov (macOS)"; \
	fi
	@echo "See COVERAGE.md for the recorded M3 baseline."

## Help
help:
	@echo "Available targets:"
	@echo "  make lint       - Run shellcheck on all scripts"
	@echo "  make test       - Run bats tests"
	@echo "  make version-check - Verify all version strings match VERSION"
	@echo "  make test-docker - Run bats tests in container (no local bats needed)"
	@echo "  make coverage   - Report coverage (pytest --cov; kcov for bash if installed)"
	@echo "  make security-scan - Scan git history for secrets (gitleaks)"
	@echo "  make all        - Run lint, test, and version-check"
	@echo "  make check-deps - Verify required tools are installed"
	@echo "  make install    - Install to /usr/local/bin"
	@echo "  make uninstall  - Remove from /usr/local/bin"
	@echo "  make clean      - Remove test artifacts"
