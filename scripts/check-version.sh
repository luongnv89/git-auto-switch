#!/usr/bin/env bash
#
# check-version.sh - single-source guard for the release version string.
#
# VERSION is the canonical source. Every shipped copy below must match it:
#   package.json                 (.version)
#   package-lock.json            (.version and .packages[""].version)
#   pyproject.toml               (project.version)
#   git_auto_switch/__init__.py  (__version__)
#   lib/core/constants.sh        (GAS_VERSION)
#
# Usage:
#   scripts/check-version.sh [--sync] [repo-root]
#
#   default    check mode: print each source, exit 1 on any divergence
#   --sync     rewrite every derived copy from VERSION (release bumps)
#   repo-root  tree to inspect (default: this script's repo root)
#

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-version.sh [--sync] [repo-root]

VERSION is the single canonical source of the release version.

  (default)   check mode: verify every derived copy matches VERSION
              (exit 1 on divergence, 2 on a missing/unreadable source)
  --sync      rewrite each derived copy from VERSION (release bumps)
  repo-root   tree to inspect (default: the script's own repo root)

Derived copies: package.json, package-lock.json, pyproject.toml,
git_auto_switch/__init__.py, lib/core/constants.sh (GAS_VERSION).
EOF
}

sync_mode=0
root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync|--fix)
      sync_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      root="$1"
      shift
      ;;
  esac
done

if [[ -z "$root" ]]; then
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

command -v jq >/dev/null 2>&1 || {
  echo "check-version: jq not found (required - see make check-deps)" >&2
  exit 2
}

version_file="$root/VERSION"
if [[ ! -f "$version_file" ]]; then
  echo "check-version: VERSION not found at $version_file" >&2
  exit 2
fi

canonical="$(tr -d '[:space:]' < "$version_file")"
if [[ -z "$canonical" ]]; then
  echo "check-version: VERSION is empty" >&2
  exit 2
fi

# --- extractors: print the version each derived copy currently carries ----

pkg_json_version() { jq -r '.version' "$root/package.json"; }
pkg_lock_versions() { jq -r '.version, .packages[""].version' "$root/package-lock.json"; }
toml_version() { sed -n 's/^version = "\(.*\)"/\1/p' "$root/pyproject.toml" | head -1; }
py_version() { sed -n 's/^__version__ = "\(.*\)"/\1/p' "$root/git_auto_switch/__init__.py"; }
sh_version() { sed -n 's/^readonly GAS_VERSION="\(.*\)"/\1/p' "$root/lib/core/constants.sh"; }

# --- sync helpers -----------------------------------------------------------

# Rewrite a JSON file through jq (same-fs tmp + mv keeps the write atomic).
rewrite_json() {
  local filter="$1" path="$2"
  jq --arg v "$canonical" "$filter" "$path" > "$path.tmp.$$" || {
    rm -f "$path.tmp.$$"
    return 1
  }
  mv "$path.tmp.$$" "$path"
}

# Rewrite one anchored line via a complete sed substitution (same-fs tmp + mv).
rewrite_sed() {
  local expr="$1" path="$2"
  sed "$expr" "$path" > "$path.tmp.$$" || {
    rm -f "$path.tmp.$$"
    return 1
  }
  mv "$path.tmp.$$" "$path"
}

sync_copies() {
  local missing=0
  for f in package.json package-lock.json pyproject.toml \
    git_auto_switch/__init__.py lib/core/constants.sh; do
    if [[ ! -f "$root/$f" ]]; then
      echo "check-version: missing $root/$f" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || return 2

  # shellcheck disable=SC2016  # $v is jq's --arg variable, not a shell one
  rewrite_json '.version = $v' "$root/package.json"
  # shellcheck disable=SC2016  # same: jq filter, not shell expansion
  rewrite_json '.version = $v | .packages[""].version = $v' "$root/package-lock.json"
  rewrite_sed "s/^version = \".*\"/version = \"$canonical\"/" "$root/pyproject.toml"
  rewrite_sed "s/^__version__ = \".*\"/__version__ = \"$canonical\"/" "$root/git_auto_switch/__init__.py"
  rewrite_sed "s/^readonly GAS_VERSION=\".*\"/readonly GAS_VERSION=\"$canonical\"/" "$root/lib/core/constants.sh"
}

# --- check ------------------------------------------------------------------

failures=0

# report <label> <actual> [<actual>...] — every value must equal VERSION.
report() {
  local label="$1"
  shift
  local actual
  for actual in "$@"; do
    if [[ "$actual" == "$canonical" ]]; then
      printf '  ok        %-28s %s\n' "$label" "$actual"
    else
      printf '  MISMATCH  %-28s %s (VERSION: %s)\n' "$label" "${actual:-<missing>}" "$canonical"
      failures=$((failures + 1))
    fi
  done
}

run_checks() {
  echo "VERSION (canonical): $canonical"

  if [[ -f "$root/package.json" ]]; then
    report "package.json" "$(pkg_json_version)"
  else
    report "package.json" ""
  fi

  if [[ -f "$root/package-lock.json" ]]; then
    local lock_versions
    # `|| true`: a malformed lockfile reports as <missing>, not a silent abort
    lock_versions="$(pkg_lock_versions || true)"
    # intentional word split: one version per line
    # shellcheck disable=SC2086
    report "package-lock.json" $lock_versions
  else
    report "package-lock.json" ""
  fi

  if [[ -f "$root/pyproject.toml" ]]; then
    report "pyproject.toml" "$(toml_version)"
  else
    report "pyproject.toml" ""
  fi

  if [[ -f "$root/git_auto_switch/__init__.py" ]]; then
    report "__init__.py" "$(py_version)"
  else
    report "__init__.py" ""
  fi

  if [[ -f "$root/lib/core/constants.sh" ]]; then
    report "GAS_VERSION" "$(sh_version)"
  else
    report "GAS_VERSION" ""
  fi
}

if [[ "$sync_mode" -eq 1 ]]; then
  echo "Syncing derived version copies from VERSION..."
  sync_copies
fi

run_checks

if [[ "$failures" -gt 0 ]]; then
  echo "check-version: $failures source(s) diverge from VERSION ($canonical)" >&2
  exit 1
fi

if [[ "$sync_mode" -eq 1 ]]; then
  echo "check-version: all copies synced to $canonical"
else
  echo "check-version: all sources agree ($canonical)"
fi
