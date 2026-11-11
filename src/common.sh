#!/usr/bin/env bash
# Both platforms, once linux.sh or macos.sh has put mise on PATH: link the
# global tool list, install it, wire up the shell, and check the result.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MISE_CONF_D="${XDG_CONFIG_HOME:-$HOME/.config}/mise/conf.d"

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

verify mise

echo "==> Linking the global tool list"
# A symlink into this clone, so `git pull && mise install` is the whole update.
# conf.d rather than config.toml so your own global config is never replaced.
mkdir -p "$MISE_CONF_D"
ln -sfn "$REPO_DIR/src/mise/config.toml" "$MISE_CONF_D/toolchain.toml"
echo "  $MISE_CONF_D/toolchain.toml -> $REPO_DIR/src/mise/config.toml"

echo "==> Installing tools with mise"
mise trust --quiet "$REPO_DIR/src/mise/config.toml"
mise install --yes
eval "$(mise activate bash --shims)"

echo "==> Verifying tools"
for tool in az gh terraform tflint terraform-docs checkov python uv node pre-commit \
    shellcheck actionlint gitleaks jq yq kubectx psql; do
  verify "$tool"
done
verify kubelogin --version
verify pwsh -v
verify kubectl version --client
verify helm version
verify k9s version

echo "==> Installing Azure PowerShell module"
pwsh -NoProfile -Command "Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber"
pwsh -NoProfile -Command "Import-Module Az.Accounts; Write-Host \"  ok: Az \$(Get-Module Az.Accounts -ListAvailable | Select-Object -First 1 -ExpandProperty Version)\""

echo "==> Configuring shells"

_append_if_missing() {
  local file="$1" marker="$2" content="$3"
  touch "$file"
  grep -qF "$marker" "$file" 2>/dev/null && { echo "  already configured: $file"; return; }
  printf '\n%s\n' "$content" >> "$file"
  echo "  configured: $file"
}

# Shims rather than `mise activate`: a shim picks the version the current
# directory's mise.toml pins at the moment the command runs, so non-interactive
# shells (VS Code tasks, Claude Code, make) get the repo's version too.
# `mise activate` only updates PATH from an interactive prompt hook.
BREW_ENV=""
if [[ "$(uname)" == "Darwin" ]]; then
  # shellcheck disable=SC2016  # expands at shell startup, not here
  BREW_ENV='eval "$('"$(command -v brew)"' shellenv)"
export PATH="$(brew --prefix libpq)/bin:$PATH"'
fi

PROFILE_BLOCK="# toolchain: mise
${BREW_ENV:+$BREW_ENV
}command -v mise &>/dev/null && eval \"\$(mise activate bash --shims)\""
BASHRC_BLOCK="${PROFILE_BLOCK}
command -v kubectl &>/dev/null && source <(kubectl completion bash)
command -v helm &>/dev/null && source <(helm completion bash)"
ZSH_PROFILE_BLOCK="${PROFILE_BLOCK//activate bash/activate zsh}"
ZSHRC_BLOCK="${ZSH_PROFILE_BLOCK}
autoload -Uz compinit && compinit
command -v kubectl &>/dev/null && source <(kubectl completion zsh)
command -v helm &>/dev/null && source <(helm completion zsh)"

_append_if_missing ~/.profile "# toolchain: mise" "$PROFILE_BLOCK"
_append_if_missing ~/.bashrc "# toolchain: mise" "$BASHRC_BLOCK"
if [[ "$(uname)" == "Darwin" ]] || command -v zsh &>/dev/null; then
  _append_if_missing ~/.zprofile "# toolchain: mise" "$ZSH_PROFILE_BLOCK"
  _append_if_missing ~/.zshrc "# toolchain: mise" "$ZSHRC_BLOCK"
fi

echo "==> Checking Docker"
# Not installed here: on WSL, Docker Desktop's WSL integration provides it, and
# a daemon is too machine-specific for a bootstrap script to choose for you.
if ! command -v docker &>/dev/null; then
  echo "  WARN: no docker CLI. Install Docker Desktop and enable WSL integration for this distro"
  echo "        (or Docker Engine: https://docs.docker.com/engine/install/ubuntu/)."
elif ! docker info &>/dev/null; then
  echo "  WARN: docker is installed but the daemon is not reachable. Start Docker Desktop."
else
  verify docker
fi
