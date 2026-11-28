#!/usr/bin/env bash
# Run after src/setup.sh on Linux: every shared library Playwright's Chromium
# links against resolves, so the apps' browser tests can launch it. The sonames
# match the packages src/linux.sh installs. GitHub's ubuntu-24.04 runner ships
# them all already, so only `make test` (a bare ubuntu:24.04) really tests the
# install; CI's run only catches a soname that stops resolving.
set -euo pipefail

SONAMES=(
  libasound.so.2 libatk-1.0.so.0 libatk-bridge-2.0.so.0 libatspi.so.0
  libcairo.so.2 libcups.so.2 libdbus-1.so.3 libdrm.so.2 libgbm.so.1
  libglib-2.0.so.0 libgio-2.0.so.0 libgobject-2.0.so.0
  libnspr4.so libnss3.so libnssutil3.so libsmime3.so libpango-1.0.so.0
  libX11.so.6 libxcb.so.1 libXcomposite.so.1 libXdamage.so.1 libXext.so.6
  libXfixes.so.3 libxkbcommon.so.0 libXrandr.so.2
)

echo "==> Checking Chromium's system libraries"
# The linker cache's first column is each library's soname.
cache="$(/sbin/ldconfig -p | awk 'NR > 1 { print $1 }')"
missing=()
for so in "${SONAMES[@]}"; do
  grep -qxF "$so" <<<"$cache" || missing+=("$so")
done
if ((${#missing[@]})); then
  echo "  FAIL: not found: ${missing[*]}"
  exit 1
fi
echo "  ok: all ${#SONAMES[@]} libraries Chromium needs"
