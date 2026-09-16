# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-16

### Added
- `gas validate` and `gas apply` are now scriptable: new `--yes` /
  `--no-prompt` flags skip confirmations, and `gas validate --check-ssh`
  runs SSH connection tests without prompting (#29)
- `gas apply --no-passphrase` flag plus `GAS_SSH_PASSPHRASE` /
  `GAS_NO_PASSPHRASE` environment variables for non-interactive control
  of SSH-key passphrase generation (#15)
- Repository scan cache: repo discovery results are cached per workspace
  under `~/.git-auto-switch/cache/repo-scans/` for `GAS_SCAN_CACHE_TTL`
  seconds (default 300, `0` disables), so back-to-back `gas apply` /
  `gas audit` runs skip re-walking the tree (#25)
- CI `security` job running gitleaks over full git history with a pinned,
  checksum-verified binary; `make security-scan` / `make security-setup`
  local gate and matching pre-commit hook; `SECURITY.md` policy (#32)
- CI and pre-commit gates now cover every shipped language (ShellCheck,
  ruff, `node --check`), the npm lockfile is verified in CI, and
  Dependabot keeps GitHub Actions current (#17, #33)
- Bats coverage for previously untested commands and a pytest suite for
  the install and main flows (#27, #28)
- Contributor/agent docs: `CLAUDE.md`, `AGENTS.md`, and recorded
  environment notes (#6, #7, #8)

### Changed
- Raised runtime floors off EOL versions: the pip package now requires
  Python >=3.11 and the npm package requires Node >=22 (#18, #19)
- Generated SSH keys are now passphrase-protected by default — an empty
  passphrase is rejected unless explicitly opted out via
  `--no-passphrase` / `GAS_NO_PASSPHRASE` (#15)
- All three install paths (pip shim, npm shim, `install-curl.sh`) share a
  single bootstrap implementation (`lib/bootstrap.sh`) — OS detection,
  package-manager detection, and dependency installs behave identically
  across install methods (#23)
- Interactive account prompts (`gas init` / `gas add`) refactored into
  single-responsibility helpers — behavior-identical internal cleanup
  with no user-visible change (#22)
- Release version is single-sourced from `VERSION` and kept in sync
  across `package.json`, `pyproject.toml`, and the launcher shims by
  `scripts/check-version.sh` (`make version-check`) (#26)
- README rewritten as a command-focused landing page; install docs now
  list per-method runtime requirements and state that PyPI/npm
  publishing is manual — CI runs lint and tests only, there is no
  automated release workflow yet (#31)

### Removed
- Deprecated `install.sh` legacy installer shim — install via
  `pip install git-auto-switch`, `npm install -g git-auto-switch`, or
  `install-curl.sh` instead (#30)
- Dead internal helpers (`validate_git_config`, `validate_directory`,
  `is_path_inside`) with zero callers — workspace/includeIf validation
  stays with `gas validate` (#34)

### Fixed
- Unified workspace path canonicalization on `expand_path` so `gas
  current`, `gas apply`, and the pre-commit hook agree on every input —
  workspaces stored with a trailing slash or a mid-path `~` now match
  correctly (#20)
- Remote rewriting now covers `ssh://git@github.com/...` origins
  (normalized to the same scp-style `git@<alias>:<path>` form as `git@`
  and `https://` remotes, including `gas apply <id>` alias switching),
  and the generated `core.sshCommand` quotes the key path after
  expanding `~` so SSH key paths containing spaces produce a working
  gitconfig (#21)
- `install-curl.sh` no longer exits 1 after a successful install — its
  EXIT trap referenced a function-local `tmp_dir`, which is unbound
  under `set -u` once `main` returns (#23)
- Account state queries no longer spawn one jq process per field —
  fields are extracted in a single jq projection in `validate_state`,
  `audit`, `validate`, and `apply` (~53% faster state validation on a
  10-account fixture), and `update_account` allowlists writable fields
  with type-preserving writes so `workspaces` keeps its array type (#24)
- `gas validate` / `gas apply` no longer hang on prompts or abort
  mid-run when stdin is not a TTY (CI, scripts, `</dev/null`) — every
  interactive prompt is now gated on `[[ -t 0 ]]` (#29)
- `gas audit` no longer aborts when a discovered repo cannot be entered —
  unreadable entries are skipped and reported under a new "Failed to
  audit" summary count; account lookups use `jq --arg` instead of string
  interpolation so account IDs cannot break the query (#13)
- The `gas` symlink is now relative, fixing a dangling link when the
  repo is checked out somewhere other than its original path (#11)

### Security
- Enforce `0700` on `~/.git-auto-switch` (and backup dirs) and `0600` on
  `config.json` and its backups; enforce `0700` on `~/.ssh` when
  applying SSH config (#32)
- github.com SSH host keys are verified against GitHub's published
  fingerprints before being written to `known_hosts` — `gas apply`
  refuses to trust unverified `ssh-keyscan` results (#15)
- Installers verify downloaded payloads before executing them:
  `install-curl.sh` supports SHA-256 verification via `GAS_CHECKSUM`,
  `--checksum`, or a `.sha256` sidecar and refuses to run on mismatch;
  the pip shim downloads-then-verifies instead of piping `curl` output
  into a shell (#14)

## [0.2.0] - 2026-04-28

### Added
- `gas apply <id|ssh_alias>` applies a single account's identity to the
  current repository (sets local user.name/user.email and rewrites the
  origin remote to use the SSH alias) (#2, #3)
- `gas current` command to show the active account for the current
  directory
- `gas audit --fix` option to auto-correct detected issues
- `gas whoami` remote URL validation
- Multiple workspaces per account
- SSH authentication check during account validation
- Validation and confirmation step after entering account info
- Save progress on Ctrl+C during init
- Packaging for pip and npm, plus curl install script
- Brand logo in README
- MIT License, Contributing guidelines
- GitHub Actions CI workflow (ShellCheck + bats tests)
- Makefile, EditorConfig, expanded bats test suite

### Fixed
- False email mismatch warning in `whoami`
- Arithmetic increment failures under `set -e`
- `mapfile` and unbound-variable issues on Bash 3.2
- Empty account ID bug in `init`/`add`
- Symlink resolution in install targets
- ShellCheck warnings (variable quoting, `read -r` flag)

## [0.1.0] - 2024-01-01

### Added
- Initial release
- Multi-account SSH key management
- Folder-based Git identity switching using `includeIf.gitdir:`
- Pre-commit email guard hook
- Remote URL rewriting to use SSH aliases
- Automatic backup before changes
