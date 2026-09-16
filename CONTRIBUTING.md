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

    Minimum versions: Bash 3.2+, Git 2.13+, bats-core 1.14.0 (pinned, see
     below), Node >=22, Python >=3.11.
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

## Fresh checkout → working suite (recorded)

From a clean checkout, this single sequence ends with `bats test/`
executing (F-TEST-004):

```bash
git clone https://github.com/luongnv89/git-auto-switch.git
cd git-auto-switch
make check-deps && bats test/
```

Toolchain pin: **bats-core v1.14.0** everywhere — local install, CI
(`bats-core/bats-action`), and the `bats/bats:1.14.0` image used by
`make test-docker` below. Install the pin exactly with:

```bash
git clone --branch v1.14.0 --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
sudo /tmp/bats-core/install.sh /usr/local
# ...or user-local (ensure ~/.local/bin is on your PATH):
/tmp/bats-core/install.sh ~/.local
```

No bats and can't install? Run the same suite containerized — only
Docker is needed (git, jq, and an ssh client are added inside the
container for you):

```bash
make test-docker
```

## Environment Variables

No required env vars beyond `HOME`.

- Runtime state lives under `~/.git-auto-switch/` (config + backups).
- `make install` targets `~/.local/bin`, so ensure `~/.local/bin` is on
  your `PATH`. No API keys, tokens, or service URLs are needed for
  build/test.

## Build and Test (recorded commands)

 ```bash
 make lint     # ShellCheck on git-auto-switch, install-curl.sh, lib/**/*.sh, scripts/*.sh
 bats test/    # bats suite
 make test     # same suite via Make (wraps `bats test/`)
 make version-check  # all shipped version copies must match VERSION
 make all      # all three: lint + test + version-check
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
 - Version single-source: `VERSION` is canonical; `package.json`,
   `package-lock.json`, `pyproject.toml` (`project.version`),
   `git_auto_switch/__init__.py` (`__version__`), and `GAS_VERSION` in
   `lib/core/constants.sh` are derived copies. `make version-check` fails
   on divergence; `scripts/check-version.sh --sync` rewrites them from
   `VERSION` on a release bump.

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
