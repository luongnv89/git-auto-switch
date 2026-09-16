# Security Policy

## Reporting a Vulnerability

Please report vulnerabilities privately via GitHub's "Report a
vulnerability" flow (Security tab → Advisories), or open an issue marked
with the `dim:sec` label when the report contains no exploitable detail.
Do not file public issues for unpatched, exploitable findings.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x (latest release) | yes |
| < 0.2.0 | no — upgrade |

## Hardening Posture

- **Install integrity** — `install-curl.sh` downloads the release tarball
  to a file and verifies its SHA256 before anything is extracted or run
  (`--checksum` / `GAS_CHECKSUM`, then the `<url>.sha256` sidecar). On
  mismatch the download is deleted and the install aborts. It never pipes
  a network stream into a shell or into `tar`.
- **State file permissions** — `~/.git-auto-switch/` is `0700`;
  `config.json` and timestamped backups are `0600`; `~/.ssh` is enforced
  `0700` and `~/.ssh/config` `0600` whenever `gas` touches them.
- **Secret scanning** — the CI `security` job runs gitleaks over the full
  git history on every push and pull request, using a pinned release
  binary whose SHA256 is verified against upstream `checksums.txt` before
  it executes. The same gate is available locally and as a pre-commit
  hook (see below).
- **Identity guard** — the generated pre-commit hook aborts a commit when
  `user.email` does not match the workspace's expected account email.
- **No secrets in logs** — `gas` never prints private keys, passphrases,
  or tokens; the only key material echoed is the *public* key after
  generation so it can be added to GitHub.

## Verifying the Posture

```bash
make security-scan   # gitleaks over full history — zero findings expected
bats test/           # full suite must stay green
```

`make security-scan` prefers a local `gitleaks` install and falls back to
the pinned `zricethezav/gitleaks` docker image; with neither available it
fails closed with install instructions. `make security-setup` is an
alias for the same gate.

With `pre-commit install` active, the pinned gitleaks hook also scans
each commit before it lands.
