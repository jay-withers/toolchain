#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

installed() { command -v "$1" &>/dev/null; }

verify() {
  local bin=$1; shift
  local args=("$@")
  [[ ${#args[@]} -eq 0 ]] && args=("--version")
  if command -v "$bin" &>/dev/null; then
    echo "  ok: $bin $("$bin" "${args[@]}" 2>&1 | head -1)"
  else
    echo "  FAIL: $bin not found"
    exit 1
  fi
}

if ! installed brew; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi
verify brew

echo "==> Installing packages from Brewfile"
brew bundle --file="$REPO_DIR/config/Brewfile"

echo "==> Verifying Brewfile tools"
for tool in git curl wget jq yq az kubectx tfenv terraform-docs checkov pre-commit gitleaks actionlint shellcheck node commitlint; do
  verify "$tool"
done
verify kubectl version --client
verify helm version
verify k9s version

echo "==> Installing macOS-specific packages"
brew trust azure/kubelogin
brew bundle --file="$REPO_DIR/config/Brewfile.macos"
verify kubelogin

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        TFLINT_ARCH="amd64" ;;
  aarch64|arm64) TFLINT_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac
curl -fsSL "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_darwin_${TFLINT_ARCH}.zip" \
  -o /tmp/tflint.zip
unzip -o /tmp/tflint.zip tflint -d /usr/local/bin
chmod +x /usr/local/bin/tflint
rm /tmp/tflint.zip
verify tflint
