# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- MIT License
- Contributing guidelines
- GitHub Actions CI workflow (ShellCheck + bats tests)
- Makefile for development tasks
- EditorConfig for consistent formatting
- Bats test framework with tests for cleanup and hooks modules

### Fixed
- ShellCheck warnings (variable quoting, read -r flag)

## [0.1.0] - 2024-01-01

### Added
- Initial release
- Multi-account SSH key management
- Folder-based Git identity switching using `includeIf.gitdir:`
- Pre-commit email guard hook
- Remote URL rewriting to use SSH aliases
- Automatic backup before changes
