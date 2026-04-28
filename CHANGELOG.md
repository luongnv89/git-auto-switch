# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
