# git-auto-switch

[![CI](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml/badge.svg)](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A CLI tool for managing multiple GitHub accounts with automatic identity switching based on workspace folders.

## Features

- Manage multiple GitHub accounts with separate SSH keys
- **Multiple workspaces per account** - map several folders to the same identity
- Automatic Git identity switching based on workspace folders
- Pre-commit hook to prevent wrong-email commits
- SSH key validation and GitHub authentication check during setup
- Audit repositories and auto-fix identity issues
- Automatic remote URL rewriting (HTTPS to SSH)
- Show current active account for any directory

## Requirements

- Bash 3.2+
- Git 2.13+ (for conditional includes)
- jq (JSON processor)

## Installation

### Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/git-auto-switch/main/install-curl.sh | bash
```

To uninstall:
```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/git-auto-switch/main/install-curl.sh | bash -s uninstall
```

### pip / uv

```bash
pip install git-auto-switch
# or
uv pip install git-auto-switch
```

### npm

```bash
npm install -g git-auto-switch
```

### From Source

```bash
git clone https://github.com/luongnv89/git-auto-switch.git
cd git-auto-switch

# Install dependencies
brew install jq  # macOS
# or: sudo apt install jq  # Ubuntu/Debian

# Install CLI globally
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

# Show current active account
gas current
# or:
gas whoami

# List all configured accounts
gas list

# Validate configuration
gas validate

# Audit repositories for identity issues
gas audit

# Audit and auto-fix issues
gas audit --fix

# Apply configuration after manual changes
gas apply
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
| `audit [--fix]` | Audit repositories for identity mismatches (--fix to auto-fix) |
| `current` | Show current active account for this directory (alias: `whoami`) |
| `help` | Show help message |
| `version` | Show version |

## How It Works

1. **SSH Keys**: Uses separate SSH keys for each account (generates ed25519 keys if needed)
2. **SSH Config**: Adds host aliases (e.g., `gh-work`, `gh-personal`) to `~/.ssh/config`
3. **Git Config**: Uses `includeIf.gitdir:` to auto-switch identity based on workspace
4. **Pre-commit Hook**: Validates email before each commit to prevent mistakes
5. **Remote Rewriting**: Converts `git@github.com` to `git@gh-alias` for proper SSH key usage

## Workflow

### Adding a New Account

When you run `gas add`, the tool will:

1. Prompt for account details (name, workspaces, SSH key, Git identity)
2. Validate SSH key exists and test GitHub authentication
3. Automatically proceed if validation passes (no manual confirmation needed)
4. Apply configuration immediately
5. Ask if you want to add another account

### Checking Current Account

```bash
$ gas current

========================================
  Current Account: work
========================================

  Account ID:  work
  Git Name:    John Doe
  Git Email:   john@company.com
  SSH Alias:   gh-work

  Directory:   /home/user/workspace/work/project

  Workspaces:
    - ~/workspace/work
    - ~/projects/company
```

### Fixing Issues

The `audit --fix` command automatically fixes:
- **Email mismatches**: Removes local `user.email` so global `includeIf` takes over
- **Wrong remotes**: Rewrites `git@github.com` to use the correct SSH alias

```bash
$ gas audit --fix

Issues in: /home/user/workspace/work/repo1
  Email:
    Expected: john@company.com
    Actual:   wrong@email.com
  Fixed: Removed local user.email (will use global includeIf)
```

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
      "ssh_key_path": "~/workspace/work/.ssh/id_ed25519",
      "workspaces": [
        "~/workspace/work",
        "~/projects/company"
      ],
      "git_name": "John Doe",
      "git_email": "john@company.com"
    }
  ]
}
```

## Multiple Workspaces

Each account can have multiple workspace folders. All repositories within any of these folders will use the same Git identity and SSH key.

**Use cases:**
- Separate folders for different projects under the same account
- Client work spread across multiple directories
- Open source contributions in a dedicated folder

**Adding workspaces during setup:**
```
Workspace folder [~/workspace/work]: ~/workspace/work
Add another workspace? (leave empty to continue): ~/projects/company
Add another workspace? (leave empty to continue):
```

**Managing workspaces in the edit menu:**
```
Options:
  [2]   Manage workspaces (add/remove)

Workspace action: a
New workspace folder: ~/freelance/client-a
```

**Example output from `gas list`:**
```
[work] Work Account
  Git:    John Doe <john@company.com>
  SSH:    gh-work
  Workspaces:
    - ~/workspace/work
    - ~/projects/company
    - ~/freelance/client-a
```

## Cloning Repositories

Always use the SSH alias when cloning:

```bash
# For work account
git clone git@gh-work:org/repo.git

# For personal account
git clone git@gh-personal:user/repo.git
```

Existing repositories with `git@github.com` remotes will be automatically rewritten when you run `gas apply` or `gas audit --fix`.

## Rollback

Backups are created automatically before any changes and stored in `~/.git-auto-switch/backup/<timestamp>/`:

```bash
# List backups
ls ~/.git-auto-switch/backup/

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

# Run tests (59 tests)
make test

# Run both
make all
```

## License

[MIT](LICENSE)
