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
    shellcheck actionlint gitleaks jq yq kubectx psql starship atuin zoxide usage zsh; do
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
autoload -Uz compinit && compinit -i
command -v kubectl &>/dev/null && source <(kubectl completion zsh)
command -v helm &>/dev/null && source <(helm completion zsh)"

# Everything else interactive (prompt, autosuggestions, completions, history
# search) lives in src/shell/rc.{bash,zsh} in this clone, so `git pull` updates
# it. The rc file only sources it, guarded so a moved clone is a no-op.
# To opt out, delete the source line but keep the "# toolchain: shell" comment,
# so re-runs leave it out.
BASHRC_SHELL_BLOCK="# toolchain: shell
[[ -f \"$REPO_DIR/src/shell/rc.bash\" ]] && source \"$REPO_DIR/src/shell/rc.bash\""
ZSHRC_SHELL_BLOCK="# toolchain: shell
[[ -f \"$REPO_DIR/src/shell/rc.zsh\" ]] && source \"$REPO_DIR/src/shell/rc.zsh\""

# Before src/shell/, setup wrote a "# toolchain: prompt" block of inline lines,
# which the files above now cover. Remove that block - the marker and the
# starship, ble.sh and zsh-autosuggestions lines straight after it, nothing
# elsewhere - so nothing loads twice. If its starship line had been deleted
# (opted out), the marker becomes "# toolchain: shell" on its own, which keeps
# the opt-out. The old file is kept as <file>.toolchain-bak.
_migrate_prompt_block() {
  local file="$1" tmp
  grep -qxF "# toolchain: prompt" "$file" 2>/dev/null || return 0
  tmp="$(mktemp)"
  if ! awk '
    state == 1 {
      state = 0
      if ($0 ~ /^command -v starship &>\/dev\/null && eval "\$\(starship init (bash|zsh)\)"$/) { state = 2; next }
      print "# toolchain: shell"
    }
    state == 2 {
      if ($0 ~ /\/blesh\/ble\.sh" \]\] && source "/ || $0 ~ /\/zsh-autosuggestions\.zsh" \]\] && source "/) next
      state = 0
    }
    $0 == "# toolchain: prompt" { state = 1; next }
    { print }
    END { if (state == 1) print "# toolchain: shell" }
  ' "$file" >"$tmp"; then
    rm -f "$tmp"
    echo "  FAIL: could not migrate $file; left unchanged"
    exit 1
  fi
  cp -p "$file" "$file.toolchain-bak"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  echo "  migrated: $file (# toolchain: prompt -> # toolchain: shell; old copy in $file.toolchain-bak)"
}

_append_if_missing ~/.profile "# toolchain: mise" "$PROFILE_BLOCK"
_append_if_missing ~/.bashrc "# toolchain: mise" "$BASHRC_BLOCK"
_migrate_prompt_block ~/.bashrc
_append_if_missing ~/.bashrc "# toolchain: shell" "$BASHRC_SHELL_BLOCK"
if [[ "$(uname)" == "Darwin" ]] || command -v zsh &>/dev/null; then
  _append_if_missing ~/.zprofile "# toolchain: mise" "$ZSH_PROFILE_BLOCK"
  _append_if_missing ~/.zshrc "# toolchain: mise" "$ZSHRC_BLOCK"
  _migrate_prompt_block ~/.zshrc
  _append_if_missing ~/.zshrc "# toolchain: shell" "$ZSHRC_SHELL_BLOCK"
fi

echo "==> Making zsh the login shell"
# macOS has defaulted to zsh since Catalina. On Linux, chsh through sudo, as
# apt was. TOOLCHAIN_LOGIN_SHELL=keep leaves your login shell alone.
# The system zsh (apt's /usr/bin/zsh), not whichever zsh PATH finds first.
ZSH_PATH="$(grep -m1 -xE '/(usr/)?bin/zsh' /etc/shells 2>/dev/null || command -v zsh || true)"
LOGIN_SHELL="$( (getent passwd "$(id -un)" 2>/dev/null || true) | cut -d: -f7)"
if [[ "$(uname)" == "Darwin" ]]; then
  echo "  macOS: zsh is the default; left as is"
elif [[ "${TOOLCHAIN_LOGIN_SHELL:-}" == "keep" ]]; then
  echo "  TOOLCHAIN_LOGIN_SHELL=keep: left as $LOGIN_SHELL"
elif [[ "${LOGIN_SHELL##*/}" == "zsh" ]]; then
  echo "  already zsh ($LOGIN_SHELL)"
else
  SUDO=""
  [[ "$(id -u)" != "0" ]] && SUDO="sudo"
  $SUDO chsh -s "$ZSH_PATH" "$(id -un)"
  echo "  ok: $(id -un) now logs in to $ZSH_PATH (new terminals; bash is still there)"
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
