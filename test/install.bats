#!/usr/bin/env bats
# install.bats — checksum verification for install-curl.sh (F-SEC-001).
#
# The installer must refuse to use a download whose SHA256 does not match
# the expected value (explicit GAS_CHECKSUM or .sha256 sidecar). A tampered
# fixture must fail closed: nonzero status and no output artifact left.

setup() {
  TEST_TMP="$(mktemp -d)"
  export GAS_SOURCE_ONLY=true
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/install-curl.sh"
}

teardown() {
  if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "sha256_of_file matches the system sha256sum" {
  echo -n "gas-fixture" > "$TEST_TMP/f.txt"
  run sha256_of_file "$TEST_TMP/f.txt"
  [ "$status" -eq 0 ]
  expected="$(sha256sum "$TEST_TMP/f.txt" | awk '{print $1}')"
  [ "$output" = "$expected" ]
}

@test "verify_sha256 accepts a matching checksum" {
  echo "hello" > "$TEST_TMP/ok.txt"
  sum="$(sha256sum "$TEST_TMP/ok.txt" | awk '{print $1}')"
  run verify_sha256 "$TEST_TMP/ok.txt" "$sum"
  [ "$status" -eq 0 ]
}

@test "verify_sha256 accepts sidecar '<hash>  <filename>' format" {
  echo "hello" > "$TEST_TMP/side.txt"
  sum="$(sha256sum "$TEST_TMP/side.txt")"
  run verify_sha256 "$TEST_TMP/side.txt" "$sum"
  [ "$status" -eq 0 ]
}

@test "verify_sha256 refuses a tampered fixture" {
  echo "original-content" > "$TEST_TMP/victim.txt"
  sum="$(sha256sum "$TEST_TMP/victim.txt" | awk '{print $1}')"
  echo "attacker-payload" >> "$TEST_TMP/victim.txt"
  run verify_sha256 "$TEST_TMP/victim.txt" "$sum"
  [ "$status" -ne 0 ]
}

@test "download_and_verify refuses a tampered tarball (sidecar mismatch)" {
  mkdir -p "$TEST_TMP/src/gas"
  echo "payload" > "$TEST_TMP/src/gas/file.txt"
  tar -czf "$TEST_TMP/pkg.tar.gz" -C "$TEST_TMP/src" gas
  sha256sum "$TEST_TMP/pkg.tar.gz" | awk '{print $1}' > "$TEST_TMP/pkg.tar.gz.sha256"
  echo "attacker-payload" >> "$TEST_TMP/pkg.tar.gz"
  run download_and_verify "file://$TEST_TMP/pkg.tar.gz" "$TEST_TMP/out.tar.gz"
  [ "$status" -ne 0 ]
  [ ! -f "$TEST_TMP/out.tar.gz" ]
}

@test "download_and_verify accepts an intact tarball (sidecar match)" {
  mkdir -p "$TEST_TMP/src/gas"
  echo "payload" > "$TEST_TMP/src/gas/file.txt"
  tar -czf "$TEST_TMP/pkg.tar.gz" -C "$TEST_TMP/src" gas
  sha256sum "$TEST_TMP/pkg.tar.gz" | awk '{print $1}' > "$TEST_TMP/pkg.tar.gz.sha256"
  run download_and_verify "file://$TEST_TMP/pkg.tar.gz" "$TEST_TMP/out.tar.gz"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/out.tar.gz" ]
}

@test "download_and_verify refuses on explicit GAS_CHECKSUM mismatch" {
  export GAS_CHECKSUM="0000000000000000000000000000000000000000000000000000000000000000"
  echo "data" > "$TEST_TMP/d.bin"
  run download_and_verify "file://$TEST_TMP/d.bin" "$TEST_TMP/d.out"
  [ "$status" -ne 0 ]
  [ ! -f "$TEST_TMP/d.out" ]
}

@test "download_and_verify accepts on explicit GAS_CHECKSUM match" {
  echo "data" > "$TEST_TMP/d.bin"
  export GAS_CHECKSUM="$(sha256sum "$TEST_TMP/d.bin" | awk '{print $1}')"
  run download_and_verify "file://$TEST_TMP/d.bin" "$TEST_TMP/d.out"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/d.out" ]
}
