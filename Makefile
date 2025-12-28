.PHONY: all lint test clean check-deps help install

SHELL := /bin/bash
SCRIPTS := git-auto-switch install.sh $(wildcard lib/**/*.sh)

all: lint test

## Linting
lint:
	@echo "Running ShellCheck..."
	@shellcheck --source-path=lib $(SCRIPTS)
	@echo "ShellCheck passed!"

## Testing
test:
	@echo "Running tests..."
	@bats test/

## Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found. Install with: brew install shellcheck"; exit 1; }
	@command -v bats >/dev/null 2>&1 || { echo "bats not found. Install with: brew install bats-core"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Install with: brew install jq"; exit 1; }
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

## Cleanup
clean:
	@rm -rf test/tmp .bats-run-*

## Help
help:
	@echo "Available targets:"
	@echo "  make lint       - Run shellcheck on all scripts"
	@echo "  make test       - Run bats tests"
	@echo "  make all        - Run lint and test"
	@echo "  make check-deps - Verify required tools are installed"
	@echo "  make install    - Install to /usr/local/bin"
	@echo "  make uninstall  - Remove from /usr/local/bin"
	@echo "  make clean      - Remove test artifacts"
