#!/usr/bin/env bats

load test_helper

# Build a minimal tree carrying every derived copy at $2 (default 1.2.3).
make_version_fixture() {
  local dir="$1" version="${2:-1.2.3}"
  mkdir -p "$dir/lib/core" "$dir/git_auto_switch"
  printf '%s\n' "$version" > "$dir/VERSION"
  cat > "$dir/package.json" <<EOF
{
  "name": "git-auto-switch",
  "version": "$version"
}
EOF
  cat > "$dir/package-lock.json" <<EOF
{
  "name": "git-auto-switch",
  "version": "$version",
  "lockfileVersion": 3,
  "packages": {
    "": {
      "name": "git-auto-switch",
      "version": "$version"
    }
  }
}
EOF
  printf '[project]\nversion = "%s"\n' "$version" > "$dir/pyproject.toml"
  printf '__version__ = "%s"\n' "$version" > "$dir/git_auto_switch/__init__.py"
  printf 'readonly GAS_VERSION="%s"\n' "$version" > "$dir/lib/core/constants.sh"
}

@test "version-check: all version sources agree on the repo" {
  run bash "$PROJECT_ROOT/scripts/check-version.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all sources agree"* ]]
}

@test "version-check: fails when package.json diverges from VERSION" {
  local dir="$TEST_TEMP_DIR/vtree"
  make_version_fixture "$dir"
  jq '.version = "9.9.9"' "$dir/package.json" > "$dir/package.json.tmp"
  mv "$dir/package.json.tmp" "$dir/package.json"

  run bash "$PROJECT_ROOT/scripts/check-version.sh" "$dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISMATCH"*"package.json"* ]]
}

@test "version-check: fails when GAS_VERSION diverges" {
  local dir="$TEST_TEMP_DIR/vtree"
  make_version_fixture "$dir"
  printf 'readonly GAS_VERSION="9.9.9"\n' > "$dir/lib/core/constants.sh"

  run bash "$PROJECT_ROOT/scripts/check-version.sh" "$dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GAS_VERSION"* ]]
}

@test "version-check: catches package-lock root package divergence" {
  local dir="$TEST_TEMP_DIR/vtree"
  make_version_fixture "$dir"
  jq '.packages[""].version = "9.9.9"' "$dir/package-lock.json" > "$dir/package-lock.json.tmp"
  mv "$dir/package-lock.json.tmp" "$dir/package-lock.json"

  run bash "$PROJECT_ROOT/scripts/check-version.sh" "$dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"package-lock.json"* ]]
}

@test "version-check --sync: rewrites every divergent copy from VERSION" {
  local dir="$TEST_TEMP_DIR/vtree"
  make_version_fixture "$dir" "2.0.0"
  jq '.version = "0.0.1"' "$dir/package.json" > "$dir/package.json.tmp"
  mv "$dir/package.json.tmp" "$dir/package.json"
  printf 'readonly GAS_VERSION="0.0.1"\n' > "$dir/lib/core/constants.sh"
  printf '[project]\nversion = "0.0.1"\n' > "$dir/pyproject.toml"

  run bash "$PROJECT_ROOT/scripts/check-version.sh" --sync "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all copies synced to 2.0.0"* ]]

  # every derived copy now carries the canonical version
  [ "$(jq -r '.version' "$dir/package.json")" = "2.0.0" ]
  [ "$(jq -r '.version, .packages[""].version' "$dir/package-lock.json" | sort -u)" = "2.0.0" ]
  grep -q 'version = "2.0.0"' "$dir/pyproject.toml"
  grep -q '__version__ = "2.0.0"' "$dir/git_auto_switch/__init__.py"
  grep -q 'readonly GAS_VERSION="2.0.0"' "$dir/lib/core/constants.sh"
}

@test "version-check: missing VERSION exits non-zero" {
  mkdir -p "$TEST_TEMP_DIR/empty-tree"

  run bash "$PROJECT_ROOT/scripts/check-version.sh" "$TEST_TEMP_DIR/empty-tree"
  [ "$status" -eq 2 ]
  [[ "$output" == *"VERSION not found"* ]]
}
