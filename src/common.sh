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
    shellcheck actionlint gitleaks jq yq kubectx psql starship; do
  verify "$tool"
done
verify kubelogin --version
verify pwsh -v
verify kubectl version --client
verify helm version
verify k9s version

echo "==> Pinning pre-commit's Node"
# pre-commit ignores executables under a shims directory, so it never finds
# mise's node and builds each Node hook (commitlint) with nodeenv instead.
# Unpinned, nodeenv takes the newest Node build, and a prerelease tag
# ("27.0.0-alpha") crashes its version parser, failing every commit. Pin it to
# the node mise installed. Rewritten on each run to follow Renovate's bumps,
# but only while the file is ours.
NODEENVRC="$HOME/.nodeenvrc"
if [[ ! -e "$NODEENVRC" ]] || grep -qF "# toolchain: nodeenv" "$NODEENVRC"; then
  printf '# toolchain: nodeenv (written by toolchain/src/common.sh)\n[nodeenv]\nnode = %s\n' \
    "$(node -v | sed 's/^v//')" > "$NODEENVRC"
  echo "  $NODEENVRC -> node $(node -v)"
else
  echo "  WARN: $NODEENVRC exists and is not toolchain's; left alone. Pin [nodeenv] node there yourself."
fi

echo "==> Installing Azure PowerShell module"
pwsh -NoProfile -Command "Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber"
pwsh -NoProfile -Command "Import-Module Az.Accounts; Write-Host \"  ok: Az \$(Get-Module Az.Accounts -ListAvailable | Select-Object -First 1 -ExpandProperty Version)\""

echo "==> Configuring shells"

_append_if_missing() {
  local file="$1" marker="$2" content="$3"
  touch "$file"
  grep -qF "$marker" "$file" 2>/dev/null && { echo "  already configured: $file ($marker)"; return; }
  printf '\n%s\n' "$content" >> "$file"
  echo "  configured: $file ($marker)"
  if [[ "$marker" == "# toolchain: prompt" ]]; then
    echo "    This replaces any prompt or theme set earlier in $file. To keep yours, delete"
    echo "    the lines under '# toolchain: prompt' but keep that comment, so re-runs leave it out."
  fi
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

# The interactive prompt, a separate block so machines set up before it still
# get it. It brings back what the dev container's shell had: the git branch in
# the prompt (now from starship, in both shells) and the rest of the line
# suggested as you type (ble.sh in bash on Linux, zsh-autosuggestions in zsh
# on macOS). Each line is a no-op where its tool is missing.
# ble.sh goes last: it takes over line editing once the rest of the rc ran.
# shellcheck disable=SC2016  # expands at shell startup, not here
BASHRC_PROMPT_BLOCK='# toolchain: prompt
command -v starship &>/dev/null && eval "$(starship init bash)"
[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh" ]] && source "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"'
# shellcheck disable=SC2016  # expands at shell startup, not here
ZSHRC_PROMPT_BLOCK='# toolchain: prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"'
if [[ "$(uname)" == "Darwin" ]]; then
  ZSH_AUTOSUGGEST="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSHRC_PROMPT_BLOCK="${ZSHRC_PROMPT_BLOCK}
[[ -f \"$ZSH_AUTOSUGGEST\" ]] && source \"$ZSH_AUTOSUGGEST\""
fi

_append_if_missing ~/.profile "# toolchain: mise" "$PROFILE_BLOCK"
_append_if_missing ~/.bashrc "# toolchain: mise" "$BASHRC_BLOCK"
_append_if_missing ~/.bashrc "# toolchain: prompt" "$BASHRC_PROMPT_BLOCK"
if [[ "$(uname)" == "Darwin" ]] || command -v zsh &>/dev/null; then
  _append_if_missing ~/.zprofile "# toolchain: mise" "$ZSH_PROFILE_BLOCK"
  _append_if_missing ~/.zshrc "# toolchain: mise" "$ZSHRC_BLOCK"
  _append_if_missing ~/.zshrc "# toolchain: prompt" "$ZSHRC_PROMPT_BLOCK"
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
