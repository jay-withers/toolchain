#!/usr/bin/env bash
# macOS: Homebrew for mise and the few things mise does not manage. Every
# other tool comes from src/mise/config.toml via common.sh.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "==> Installing packages from Brewfile"
brew bundle --file="$REPO_DIR/src/Brewfile"

# libpq is keg-only: put psql on PATH without linking the whole keg.
PSQL_BIN="$(brew --prefix libpq)/bin"
export PATH="$PSQL_BIN:$PATH"
