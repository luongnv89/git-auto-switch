# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

git-auto-switch is a bash-based interactive installer that configures multiple GitHub accounts with automatic identity switching based on workspace folders. It manages SSH keys, Git identity, and commit guards.

## Running the Installer

```bash
./install.sh
```

The installer is interactive and will prompt for account details. No arguments needed.

## Architecture

The project is a modular bash script with the main entry point `install.sh` loading modules from `lib/`:

- **install.sh** - Entry point, orchestrates the flow: backup → cleanup → setup → rewrite remotes
- **lib/setup.sh** - Collects account info (labels, SSH aliases, keys, workspaces, git name/email) into parallel arrays
- **lib/ssh.sh** - Generates SSH keys (ed25519) if missing, writes SSH config with host aliases
- **lib/git.sh** - Creates per-account `.gitconfig-{name}` files, sets up `includeIf.gitdir:` conditional includes
- **lib/hooks.sh** - Installs a global pre-commit hook at `~/.git-hooks/pre-commit` that blocks commits with wrong email
- **lib/remotes.sh** - Rewrites existing repo remotes from `git@github.com:` to use SSH aliases
- **lib/cleanup.sh** - Backs up existing configs, removes previously managed SSH/Git config blocks

## Key Implementation Details

- Uses parallel arrays (`NAMES`, `ALIASES`, `KEYS`, `WORKSPACES`, `GIT_NAMES`, `GIT_EMAILS`) shared across modules
- SSH config entries are wrapped in `# === GIT-AUTO-SWITCH START/END ===` markers for safe cleanup
- Git identity switching relies on Git's `includeIf.gitdir:` feature
- Backups are stored at `~/.git-auto-switch-backup/<timestamp>/`
