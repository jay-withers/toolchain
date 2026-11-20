#!/usr/bin/env bash
# Linux (WSL Ubuntu 24.04): the few things mise does not manage, from apt,
# then mise itself. Every other tool comes from src/mise/config.toml via
# common.sh.
set -euo pipefail

SUDO=""
[[ "$(id -u)" != "0" ]] && SUDO="sudo"

# Signing keys are checked before apt trusts them, so a swapped key fails here
# rather than silently trusting whatever the URL served.
# (Named without "KEY": gitleaks reads any *KEY* assignment as a secret.)
MISE_SIGNER_FPR="24853EC9F655CE80B48E6C3A8B81C9D17413A06D"
# Same digest as dev-containers' PGDG_SIGNING_ASC_URL.
PGDG_ASC_SHA256="0144068502a1eddd2a0280ede10ef607d1ec592ce819940991203941564e8e76"
# psql major. Newer than Ubuntu's 16 because the servers it talks to are (Azure
# Flexible Server 17, a local container 18); an older client mis-renders \d.
PGDG_CLIENT_MAJOR="18"
# ble.sh (inline autosuggestions for interactive bash) publishes no checksum
# file, so it is pinned to a hand-maintained digest. Same release and digest
# dev-containers' base image used.
BLESH_URL="https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz"
BLESH_SHA256="c8612ee612bc6b10dbfd6e85c6cbdfd7caf152a12d1f9de22ea0a9d735b3080c"

echo "==> Installing apt prerequisites"
$SUDO apt-get update -qq
# bubblewrap and socat are what Claude Code's sandbox needs on Linux/WSL2;
# build-essential is for the occasional tool or Python wheel that compiles;
# libicu74 is what pwsh needs (WSL ships it, a minimal Ubuntu image does not).
$SUDO apt-get install -y -qq build-essential ca-certificates curl git gpg unzip xz-utils libicu74 bubblewrap socat
$SUDO install -dm 755 /etc/apt/keyrings
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
ARCH="$(dpkg --print-architecture)"

echo "==> Adding the mise apt repository"
tmp="$(mktemp -d)"
curl -fsSL https://mise.jdx.dev/gpg-key.pub -o "$tmp/mise.pub"
if ! gpg --show-keys --with-colons "$tmp/mise.pub" 2>/dev/null | grep -q "^fpr:*:${MISE_SIGNER_FPR}:"; then
  echo "  FAIL: mise signing key fingerprint is not ${MISE_SIGNER_FPR}"
  exit 1
fi
gpg --dearmor < "$tmp/mise.pub" | $SUDO tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=${ARCH}] https://mise.jdx.dev/deb stable main" |
  $SUDO tee /etc/apt/sources.list.d/mise.list >/dev/null

echo "==> Adding the PostgreSQL apt repository (psql ${PGDG_CLIENT_MAJOR})"
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o "$tmp/pgdg.asc"
if [[ "$(sha256sum "$tmp/pgdg.asc" | awk '{print $1}')" != "$PGDG_ASC_SHA256" ]]; then
  echo "  FAIL: PostgreSQL signing key digest changed"
  exit 1
fi
gpg --dearmor < "$tmp/pgdg.asc" | $SUDO tee /etc/apt/keyrings/pgdg.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" |
  $SUDO tee /etc/apt/sources.list.d/pgdg.list >/dev/null
rm -rf "$tmp"

$SUDO apt-get update -qq
$SUDO apt-get install -y -qq mise "postgresql-client-${PGDG_CLIENT_MAJOR}"

echo "==> Installing ble.sh (bash autosuggestions)"
# Grey, fish-style suggestions from history and completions as you type, as
# the dev container had. common.sh sources it from ~/.bashrc. A directory of
# toolchain's own, so a ble.sh you installed yourself (~/.local/share/blesh)
# is never touched. Reinstalled only when the pin changes: open shells load
# ble.sh modules lazily, and replacing them under a running shell breaks it.
BLESH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh"
if [[ "$(cat "$BLESH_DIR/.toolchain-sha256" 2>/dev/null)" == "$BLESH_SHA256" ]]; then
  echo "  already installed: $BLESH_DIR/ble.sh"
else
  tmp="$(mktemp -d)"
  curl -fsSL "$BLESH_URL" -o "$tmp/blesh.tar.xz"
  if [[ "$(sha256sum "$tmp/blesh.tar.xz" | awk '{print $1}')" != "$BLESH_SHA256" ]]; then
    echo "  FAIL: ble.sh tarball digest is not ${BLESH_SHA256}"
    exit 1
  fi
  rm -rf "$BLESH_DIR"
  mkdir -p "$BLESH_DIR"
  tar -xJ -C "$BLESH_DIR" --strip-components=1 -f "$tmp/blesh.tar.xz"
  rm -rf "$tmp"
  test -f "$BLESH_DIR/ble.sh"
  echo "$BLESH_SHA256" > "$BLESH_DIR/.toolchain-sha256"
  echo "  ok: $BLESH_DIR/ble.sh"
fi
