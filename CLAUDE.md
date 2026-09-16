# CLAUDE.md — git-auto-switch (`gas`)

`gas` switches Git identity, SSH key, and remote URL per folder — or per
repo with `gas apply <id|alias>`. A pre-commit hook blocks email mismatches
before they reach `origin`. State lives in `~/.git-auto-switch/config.json`
with timestamped backups under `~/.git-auto-switch/backup/<timestamp>/`.

## Key commands

All recorded in `CONTRIBUTING.md` (source of truth for flags); short list:

- `make lint` — ShellCheck on `git-auto-switch`, `install.sh`, `lib/**/*.sh`
- `bats test/` — full bats suite, direct invocation
- `make test` — same suite via Make (wraps `bats test/`)
- `make all` — both: lint + test
- `make check-deps` — verify `shellcheck`, `bats`, `jq` are installed
- `make install` — link `git-auto-switch`/`gas` into `~/.local/bin`

Toolchain: Bash 3.2+, Git 2.13+, `jq`, `shellcheck`, `bats-core`,
Python >=3.11, Node >=22. Install: `brew install bash git jq shellcheck
bats-core python3 node` (macOS) or `sudo apt-get install bash git jq
shellcheck bats python3 nodejs` (Debian).

## Repo layout

- `git-auto-switch` — entry point; dispatches to `lib/cli/router.sh`
- `lib/cli/` — `router.sh`, `help.sh` (command dispatch, usage)
- `lib/commands/` — one file per `gas` subcommand (`init`, `add`, `list`,
  `current`, `apply`, `audit`, `validate`, `remove`)
- `lib/core/` — `constants.sh`, `logger.sh`, `utils.sh` (shared helpers)
- `lib/state/` — `state.sh`, `account.sh` (config.json read/write)
- `lib/generators/` — `ssh_config.sh`, `git_config.sh`, `hooks.sh`
- `lib/applicators/` — `ssh.sh`, `git.sh`, `hooks.sh`, `remotes.sh`
- `test/` — bats suite, one file per command plus `test_helper.bash`
- `install.sh`, `install-curl.sh`, `bin/`, `git_auto_switch/` (PyPI/npm shims)

## Bash style

- 2-space indent (see `.editorconfig`); `Makefile` uses tabs
- Quote variables: `"$var"`, never bare `$var`
- `[[ ]]` for conditionals; `read -r` for input
- Comment non-obvious logic; follow existing patterns in `lib/`
- Keep scripts ShellCheck-clean: `make lint` must pass (see `.shellcheckrc`:
  `shell=bash`, `source-path=lib`, `SC2034` disabled)

## Version single-source

`VERSION` is the canonical release version. Every shipped copy must match
it: `package.json` (`version`), `package-lock.json`, `pyproject.toml`
(`project.version`), `git_auto_switch/__init__.py` (`__version__`), and
`lib/core/constants.sh` (`GAS_VERSION`).

- `make version-check` (`scripts/check-version.sh`) fails when any copy
  diverges; it is part of `make all`.
- `scripts/check-version.sh --sync` rewrites every copy from `VERSION` —
  run it on a release bump instead of editing the copies by hand.

Current version: `0.2.0`.

## Error-handling contract

`set -euo pipefail` is the strict-mode contract, set once per process by
the entry point — never inside sourced modules:

| Module | Contract |
|--------|----------|
| `git-auto-switch`, `gas` | `set -euo pipefail` at the top, before sourcing `lib/` |
| `lib/**/*.sh` | sourced modules — inherit the entry point's options; never `set`/`set +e` themselves; `return` for function errors, `exit` only on fatal top-level paths (unknown command, SIGINT, `log_fatal`) |
| `lib/generators/hooks.sh` | emits `set -euo pipefail` into the generated pre-commit hook |
| `scripts/*.sh` | standalone tools — `set -euo pipefail` at the top |
| `install.sh` | `set -e` (legacy installer) |
| `install-curl.sh` | explicit per-command error handling, no global `set -e` |

## Constraints

- Never edit generated output or commit secrets; no API keys/tokens needed
  for build/test (only `HOME`-relative state under `~/.git-auto-switch/`)
- Don't push to `main` unless asked; open a PR after `make all` passes
- Preserve existing `gas` subcommand names and flags (see `README.md`)

## Done when

- `make lint` and `make test` (`bats test/`) pass
- New/changed `gas <command>` behavior has a matching `test/<command>.bats`
- `VERSION`, `package.json`, `pyproject.toml` still agree (if version touched)
