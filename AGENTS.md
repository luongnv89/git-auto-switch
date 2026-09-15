# AGENTS.md

## Project

`gas` (git-auto-switch) routes Git identity, SSH key, and `origin` URL by
workspace folder, with a per-repo override (`gas apply <id|alias>`) and a
pre-commit hook that blocks email mismatches. Invariant: local repo config
must never commit as the wrong account; the hook is the last guard.

## Commands

Do not duplicate the command reference here. See `CLAUDE.md` (Key commands)
and `CONTRIBUTING.md` (Build and Test) for the recorded lint/test/install
invocations.

## Layout

- Entry: `git-auto-switch` -> `lib/cli/router.sh` + `lib/cli/help.sh`
- Commands: `lib/commands/` (one file per subcommand)
- Shared: `lib/core/`, `lib/state/`; output: `lib/generators/`,
  `lib/applicators/`
- Tests: `test/` (bats suite plus `test_helper.bash`)
- Packaging: `bin/`, `git_auto_switch/`, `install.sh`, `install-curl.sh`

## Conventions

- One bats file per command: new/changed `gas <command>` behavior needs a
  matching `test/<command>.bats`; use `test/test_helper.bash` for setup.
- To add a test: copy the closest existing bats file, cover the new flag or
  edge case, then run the recorded suite via the invocation in `CLAUDE.md`.
- Single-file check: run the one bats file for the touched command while
  iterating; run the full suite before opening a PR.
- Keep every shell file ShellCheck-clean per `.shellcheckrc`
  (`shell=bash`, `source-path=lib`, `SC2034` disabled); the recorded lint
  command in `CLAUDE.md` must pass.
- Bash deltas from defaults: 2-space indent, quoted vars (`"$var"`),
  `[[ ]]` conditionals, `read -r`; comment non-obvious logic.
- Subagents: keep research/audit output to a short summary with file paths
  and line numbers; never bypass the hook or commit identity fixtures.

## Constraints

- Never edit generated output or commit secrets; build/test needs only
  `HOME`-relative state under `~/.git-auto-switch/`.
- Don't push to `main` unless asked; open a PR after lint + tests pass.
- Preserve existing `gas` subcommand names and flags (see `README.md`).
- Release bumps keep `VERSION`, `package.json`, and `pyproject.toml` in sync.

## Done when

- The recorded lint and full-suite invocations in `CLAUDE.md` pass.
- Changed `gas <command>` behavior has a matching `test/<command>.bats`.
- Version sources still agree if the release was touched.

## Read when needed

- Commands/flags: `CLAUDE.md`, then `CONTRIBUTING.md`
- User workflows and command table: `README.md`
- Lint scope and config: `Makefile`, `.shellcheckrc`
- Test setup helpers: `test/test_helper.bash`

## Token Efficiency
- Never re-read files you just wrote or edited. You know the contents.
- Never re-run commands to "verify" unless the outcome was uncertain.
- Don't echo back large blocks of code or file contents unless asked.
- Batch related edits into single operations. Don't make 5 edits when 1 handles it.
- Skip confirmations like "I'll continue..." Just do it.
- If a task needs 1 tool call, don't use 3. Plan before acting.
- Do not summarize what you just did unless the result is ambiguous or you need additional input.
