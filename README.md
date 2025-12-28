# git-auto-switch

[![CI](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml/badge.svg)](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A CLI tool for managing multiple GitHub accounts with automatic identity switching based on workspace folders.

## Features

- Manage multiple GitHub accounts with separate SSH keys
- Automatic Git identity switching based on workspace folders
- Pre-commit hook to prevent wrong-email commits
- Audit and validate your configuration
- Automatic remote URL rewriting

## Requirements

- Bash 3.2+
- Git 2.13+ (for conditional includes)
- jq (JSON processor)

## Install

```bash
git clone https://github.com/luongnv89/git-auto-switch.git
cd git-auto-switch

# Install dependencies
brew install jq  # macOS
# or: sudo apt install jq  # Ubuntu/Debian

# Install CLI globally (optional)
make install
```

## Quick Start

```bash
# Initialize with your first account
git-auto-switch init
# or use the short alias:
gas init

# Add more accounts
gas add

# List configured accounts
gas list

# Validate configuration
gas validate

# Audit repositories for identity issues
gas audit
```

## Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize configuration (first-time setup) |
| `add` | Add a new account interactively |
| `remove [id]` | Remove an account |
| `list` | List all configured accounts |
| `apply` | Apply configuration to system |
| `validate` | Validate configuration and check for issues |
| `audit` | Audit repositories for identity mismatches |
| `help` | Show help message |
| `version` | Show version |

## How It Works

1. **SSH Keys**: Creates separate ed25519 SSH keys for each account
2. **SSH Config**: Adds host aliases (e.g., `gh-work`, `gh-personal`) to `~/.ssh/config`
3. **Git Config**: Uses `includeIf.gitdir:` to auto-switch identity based on workspace
4. **Pre-commit Hook**: Validates email before each commit to prevent mistakes

## Configuration

Configuration is stored in `~/.git-auto-switch/config.json`:

```json
{
  "version": "1.0.0",
  "accounts": [
    {
      "id": "work",
      "name": "Work Account",
      "ssh_alias": "gh-work",
      "ssh_key_path": "~/.ssh/id_ed25519_work",
      "workspace": "~/work",
      "git_name": "John Doe",
      "git_email": "john@company.com"
    }
  ]
}
```

## Cloning Repositories

Always use the SSH alias when cloning:

```bash
# For work account
git clone git@gh-work:org/repo.git

# For personal account
git clone git@gh-personal:user/repo.git
```

## Rollback

Backups are stored in `~/.git-auto-switch/backup/<timestamp>/`:

```bash
# Restore SSH config
cp ~/.git-auto-switch/backup/<timestamp>/ssh_config ~/.ssh/config

# Restore Git config
cp ~/.git-auto-switch/backup/<timestamp>/gitconfig ~/.gitconfig
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

```bash
# Install development dependencies
brew install shellcheck bats-core jq

# Run linter
make lint

# Run tests
make test

# Run both
make all
```

## License

[MIT](LICENSE)
