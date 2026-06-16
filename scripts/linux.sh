#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

installed() { command -v "$1" &>/dev/null; }

SUDO=""
[[ "$(id -u)" != "0" ]] && SUDO="sudo"

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

echo "==> Installing apt prerequisites"
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential curl git file ca-certificates unzip
verify gcc
verify curl
verify git

if ! installed brew; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
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

echo "==> Installing kubelogin and tflint"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        KUBE_ARCH="amd64" ;;
  aarch64|arm64) KUBE_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

curl -fsSL "https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-${KUBE_ARCH}.zip" \
  -o /tmp/kubelogin.zip
$SUDO unzip -j /tmp/kubelogin.zip "bin/linux_${KUBE_ARCH}/kubelogin" -d /usr/local/bin
$SUDO chmod +x /usr/local/bin/kubelogin
rm /tmp/kubelogin.zip

curl -fsSL "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_${KUBE_ARCH}.zip" \
  -o /tmp/tflint.zip
$SUDO unzip -j /tmp/tflint.zip tflint -d /usr/local/bin
$SUDO chmod +x /usr/local/bin/tflint
rm /tmp/tflint.zip

verify kubelogin
verify tflint
