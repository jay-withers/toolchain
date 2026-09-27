#!/usr/bin/env bash
set -euo pipefail

_sha256() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# verify_checksum <downloaded-file> <checksums-url> <name-as-listed-in-checksums>
#
# Fetches the published checksums file and fails loudly if the entry for
# <name-as-listed-in-checksums> is missing or doesn't match the actual
# hash of <downloaded-file>, so we never install whatever bytes the
# download URL happened to return.
verify_checksum() {
  local file="$1" checksums_url="$2" name="$3"
  local checksums expected actual

  checksums=$(curl -fsSL "$checksums_url") ||
    { echo "  FAIL: could not fetch checksums from $checksums_url"; exit 1; }

  expected=$(echo "$checksums" | grep -E "[[:space:]]${name}\$" | awk '{print $1}' | head -1)
  if [[ -z "$expected" ]]; then
    echo "  FAIL: no checksum entry for $name"
    exit 1
  fi

  actual=$(_sha256 "$file")
  if [[ "$actual" != "$expected" ]]; then
    echo "  FAIL: checksum mismatch for $name (expected $expected, got $actual)"
    exit 1
  fi

  echo "  ok: checksum verified for $name"
}
