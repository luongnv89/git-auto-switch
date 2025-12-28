# git-auto-switch

[![CI](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml/badge.svg)](https://github.com/luongnv89/git-auto-switch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A safe, interactive installer for:
- Multiple GitHub accounts
- Folder-based auto-switching
- SSH + Git identity enforcement

## Install

```bash
git clone https://github.com/luongnv89/git-auto-switch.git
cd git-auto-switch
./install.sh
```

## What it does

- One SSH key per account
- One workspace per account
- Auto-switch Git identity by folder
- Prevents wrong-email commits
- Rewrites old GitHub remotes
- Full backup before changes

## Rollback

```bash
cp ~/.git-auto-switch-backup/<timestamp>/ssh_config.bak ~/.ssh/config
cp ~/.git-auto-switch-backup/<timestamp>/gitconfig.bak ~/.gitconfig
```

## Notes

Always clone using SSH alias:
```bash
git clone git@gh-work:org/repo.git
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

```bash
# Install dependencies
brew install shellcheck bats-core

# Run linter
make lint

# Run tests
make test
```

## License

[MIT](LICENSE)
