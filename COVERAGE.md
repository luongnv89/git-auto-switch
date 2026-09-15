# Coverage (M3 baseline, F-TEST-002)

One command produces the coverage number:

```
make coverage
```

It runs Python coverage via `pytest --cov` (always) and bash coverage via
`kcov` when installed (graceful skip with exit 0 otherwise, so a clean
checkout without `kcov` stays green).

## Baseline (first measurement, 2026-09-15)

- Python (`pytest --cov=git_auto_switch tests/`): **32% total**
  (`git_auto_switch/__init__.py` 100%, `git_auto_switch/cli.py` 31%,
  11 tests in `tests/test_cli.py`, all passing).
- Bash (`lib/**/*.sh`, `git-auto-switch` via `kcov`): not measured locally —
  `kcov` was not installed. CI installs `kcov` and reports the bash number
  in the coverage job log; record it here on the first CI run that has it.
- bats suite: **72/72 passing** (`bats test/`).

## Reproduce

```
python3 -m pytest --cov=git_auto_switch --cov-report=term-missing tests/ 2>&1 | tail -5
bats test/ 2>&1 | tail -3
```

## Tools

- Python: `pip install pytest pytest-cov` (both already used by CI).
- Bash (optional locally, installed in CI): `sudo apt-get install kcov`
  (Debian/Ubuntu) or `brew install kcov` (macOS).
