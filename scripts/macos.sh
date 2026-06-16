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

echo "==> Configuring shell completions"

_append_if_missing() {
  local file="$1" marker="$2" content="$3"
  grep -qF "$marker" "$file" 2>/dev/null && { echo "  already configured: $file"; return; }
  printf '\n%s\n' "$content" >> "$file"
  echo "  configured: $file"
}

# shellcheck disable=SC2016  # variables expand at shell startup, not here
ZSH_COMPLETIONS='# toolchain completions
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
autoload -Uz compinit && compinit
command -v kubectl &>/dev/null && source <(kubectl completion zsh)
command -v helm &>/dev/null && source <(helm completion zsh)'

# shellcheck disable=SC2016  # variables expand at shell startup, not here
BASH_COMPLETIONS='# toolchain completions
[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && source "$(brew --prefix)/etc/profile.d/bash_completion.sh"
command -v kubectl &>/dev/null && source <(kubectl completion bash)
command -v helm &>/dev/null && source <(helm completion bash)'

touch ~/.zshrc
_append_if_missing ~/.zshrc "# toolchain completions" "$ZSH_COMPLETIONS"

if [[ -f ~/.bash_profile ]]; then
  _append_if_missing ~/.bash_profile "# toolchain completions" "$BASH_COMPLETIONS"
fi
