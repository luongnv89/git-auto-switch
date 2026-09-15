# Contributing to git-auto-switch

Thank you for your interest in contributing!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/luongnv89/git-auto-switch.git
   cd git-auto-switch
   ```

2. Install the toolchain (bash, git, jq, shellcheck, bats, python3, node):
   ```bash
   # macOS
   brew install bash git jq shellcheck bats-core python3 node

   # Ubuntu/Debian
   sudo apt-get install bash git jq shellcheck bats python3 nodejs
   ```

   Minimum versions: Bash 3.2+, Git 2.13+, Node >=14, Python >=3.7.
   Check yours with:
   ```bash
   bash --version && git --version && jq --version
   shellcheck --version && bats --version
   python3 --version && node --version
   ```

3. Verify your setup:
   ```bash
   make check-deps
   ```

## Environment Variables

No required env vars beyond `HOME`.

- Runtime state lives under `~/.git-auto-switch/` (config + backups).
- `make install` targets `~/.local/bin`, so ensure `~/.local/bin` is on
  your `PATH`. No API keys, tokens, or service URLs are needed for
  build/test.

## Build and Test (recorded commands)

 ```bash
 make lint     # ShellCheck on git-auto-switch, install.sh, lib/**/*.sh
 bats test/    # bats suite
 make test     # same suite via Make (wraps `bats test/`)
 make all      # both: lint + test
 ```

 ## Running Tests

 ```bash
 # Run all tests
 make test

 # Direct equivalent (recorded):
 bats test/

 # Run specific test file
 bats test/cleanup.bats

 # Run with verbose output
 bats --verbose-run test/
 ```

 ## Running Linter

 ```bash
 make lint
 ```

 ## Code Style

 - Use 2-space indentation
 - Quote variables: `"$var"` not `$var`
 - Use `[[ ]]` for conditionals (bash-specific)
 - Use `read -r` to avoid backslash escaping issues
 - Add comments for non-obvious logic
 - Follow existing patterns in the codebase
 - Keep scripts ShellCheck-clean (`make lint` must pass, see `.shellcheckrc`)

 ## Repo Etiquette

 - Bash style: 2-space indent, quoted vars, `[[ ]]`, `read -r`
   (enforced via `make lint` / ShellCheck).
 - bats per command: every `gas <command>` has a matching
   `test/<command>.bats` file; add/update the bats file with the command.
 - Version triple-source: keep `VERSION`, `package.json` (`version`), and
   `pyproject.toml` (`project.version`) in sync on every release bump.

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run `make all` to ensure lint and tests pass
5. Commit with a descriptive message
6. Push and open a Pull Request

## Reporting Issues

Please include:
- Your operating system and version
- Bash version (`bash --version`)
- Steps to reproduce the issue
- Expected vs actual behavior
