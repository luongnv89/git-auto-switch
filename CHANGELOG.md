# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CI `security` job running gitleaks over full git history with a pinned,
  checksum-verified binary; `make security-scan` / `make security-setup`
  local gate and matching pre-commit hook; `SECURITY.md` policy (#32)

### Changed
- `prompt_account_info` in `lib/state/account.sh` decomposed into
  single-responsibility helpers (field prompts, summary renderer, candidate
  validators, fix-menu state machine); behavior-identical, no function
  exceeds ~50 lines or 3 nesting levels (#22)
- Converged the Node (`bin/git-auto-switch.js`) and Python
  (`git_auto_switch/cli.py`) launchers plus `install-curl.sh` onto a single
  dependency bootstrap, `lib/bootstrap.sh` — OS detection, package-manager
  detection, dependency install flows, and banners now exist in exactly one
  place (F-CLEAN-002, F-DEAD-002, F-DEAD-004) (#23)
- README install docs now list per-method runtime requirements (Python
  >=3.11 for pip, Node >=22 for npm, curl/tar/sha256 tool for the curl
  installer) and state that PyPI/npm publishing is manual — CI runs lint
  and tests only, there is no automated release workflow yet (#31)

### Removed
- Deprecated `install.sh` legacy installer shim — install via
  `pip install git-auto-switch`, `npm install -g git-auto-switch`, or
  `install-curl.sh` instead (#30)
- Dead `validate_git_config` helper in `lib/applicators/git.sh` — zero
  callers and zero test references; workspace/includeIf validation stays
  with `gas validate` (#34)
- Dead `validate_directory` and `is_path_inside` helpers in
  `lib/core/utils.sh` — zero callers and zero test references (#34)

### Fixed
- Unified workspace path canonicalization on `expand_path` so `gas current`,
  `gas apply`, and the pre-commit hook agree on every input — workspaces
  stored with a trailing slash or a mid-path `~` now match correctly (#20)
- Remote rewriting now covers `ssh://git@github.com/...` origins — they are
  normalized to the same scp-style `git@<alias>:<path>` form as `git@` and
  `https://` remotes, including `gas apply <id>` alias switching (#21)
- Generated `core.sshCommand` now quotes the key path (and expands `~`
  first), so accounts whose SSH key path contains spaces produce a working
  gitconfig (#21)
- `install-curl.sh` no longer exits 1 after a successful install — its EXIT
  trap referenced a function-local `tmp_dir`, which is unbound under
  `set -u` once `main` returns (#23)
- Collapsed the jq N+1 query patterns: account fields are now extracted in a
  single jq projection in `validate_state`, `audit`, `validate`, and `apply`
  (~53% faster state validation on a 10-account fixture), and
  `update_account` now allowlists writable fields with type-preserving
  writes so `workspaces` keeps its array type (#24)

### Security
- Enforce `0700` on `~/.git-auto-switch` (and backup dirs) and `0600` on
  `config.json` and its backups; enforce `0700` on `~/.ssh` when applying
  SSH config (#32)

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
