.PHONY: all lint test clean check-deps help

SHELL := /bin/bash
SCRIPTS := install.sh $(wildcard lib/*.sh)

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
	@echo "All dependencies installed!"

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
	@echo "  make clean      - Remove test artifacts"
