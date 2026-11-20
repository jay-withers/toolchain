# shellcheck shell=bash disable=SC1090,SC1091  # sources computed paths
# Interactive bash, sourced from ~/.bashrc by the line under "# toolchain: shell"
# that src/common.sh writes. A file in this clone rather than lines in your rc,
# so `git pull` updates it. Every line is a no-op where its tool is missing.
# zsh is the default shell (src/shell/rc.zsh); this keeps bash comfortable too.

[[ $- == *i* ]] || return 0
# macOS's /bin/bash is 3.2: no `source <(...)`, no ble.sh. zsh is the shell there.
(( BASH_VERSINFO[0] >= 4 )) || return 0

# Claude Code comes from mise at the version Renovate pins; its own updater
# would replace it behind mise's back.
export DISABLE_AUTOUPDATER=1

# ble.sh: grey suggestions from history and completions as you type (→ accepts),
# plus syntax highlighting. Loaded first and attached last, as its README asks,
# so the prompt and history hooks below register with it.
_toolchain_blesh="${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"
[[ -f $_toolchain_blesh ]] && source "$_toolchain_blesh" --attach=none
unset _toolchain_blesh

# Calls through a mise shim cost a few hundred ms, and atuin and zoxide run on
# every command and cd. So resolve the real install directories once, in one
# call, and put the shell tools' first on PATH (no repo pins those, so this
# never shadows a per-repo version). The rest feed the completion cache.
_toolchain_paths="$(command -v mise &>/dev/null && mise bin-paths starship atuin zoxide usage gh kubectl helm pypi:azure-cli </dev/null 2>/dev/null)"
_toolchain_dir() { grep -m1 "/installs/$1/" <<<"$_toolchain_paths"; }
for _toolchain_tool in usage zoxide atuin starship; do
  _toolchain_d="$(_toolchain_dir "$_toolchain_tool")"
  [[ -n $_toolchain_d && :$PATH: != *":$_toolchain_d:"* ]] && PATH="$_toolchain_d:$PATH"
done

# Generating gh's, kubectl's, helm's and az's completion scripts takes from a
# quarter to most of a second each, so each
# is cached, tagged with the real binary's path. mise installs each version in
# its own directory, so a bump changes the path and regenerates the cache.
# Written to a temp file and moved into place, so shells starting together
# never read half of one. Usage: _toolchain_cached <name> <binary> <cmd...>
_toolchain_cached() {
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/toolchain/$1" tag="# toolchain cache: $2" first=""
  [[ -n $2 && -e $2 ]] || return 0
  [[ -s $cache ]] && IFS= read -r first <"$cache"
  if [[ $first != "$tag" ]]; then
    mkdir -p "${cache%/*}"
    if ! { printf '%s\n' "$tag" && "${@:3}"; } >"$cache.$$" 2>/dev/null ||
      ! mv -f "$cache.$$" "$cache"; then
      rm -f "$cache.$$"
      return 0
    fi
  fi
  source "$cache"
}
_toolchain_gh="$(_toolchain_dir gh)"
_toolchain_gh="${_toolchain_gh:+$_toolchain_gh/gh}"
[[ -n $_toolchain_gh ]] || _toolchain_gh="$(command -v gh)"
# az's completer is argcomplete's, beside the real az behind mise's symlink.
_toolchain_az="$(_toolchain_dir pypi-azure-cli)"
_toolchain_az="$(readlink -f "${_toolchain_az:-/nonexistent}/az" 2>/dev/null)"
_toolchain_az_complete="${_toolchain_az%/*}/register-python-argcomplete"

# Completions. mise's needs `usage`, which the global mise config installs,
# and is quick enough to run each time.
_toolchain_cached gh.bash "$_toolchain_gh" "$_toolchain_gh" completion -s bash
for _toolchain_tool in kubectl helm; do
  _toolchain_d="$(_toolchain_dir "$_toolchain_tool")"
  _toolchain_d="${_toolchain_d:+$_toolchain_d/$_toolchain_tool}"
  [[ -n $_toolchain_d ]] || _toolchain_d="$(command -v "$_toolchain_tool")"
  _toolchain_cached "$_toolchain_tool.bash" "$_toolchain_d" "$_toolchain_d" completion bash
done
command -v mise &>/dev/null && command -v usage &>/dev/null && source <(mise completion bash)
[[ -x $_toolchain_az_complete ]] && _toolchain_cached az.bash "$_toolchain_az_complete" "$_toolchain_az_complete" az
unset -f _toolchain_cached _toolchain_dir
unset _toolchain_paths _toolchain_tool _toolchain_d _toolchain_gh _toolchain_az _toolchain_az_complete

# toolchain's lean starship config, unless you have your own.
[[ -z ${STARSHIP_CONFIG-} && ! -f $HOME/.config/starship.toml ]] &&
  export STARSHIP_CONFIG="${BASH_SOURCE[0]%/*}/starship.toml"

# Prompt with the git branch and status; `z <part of a path>` to jump to a
# directory you use; atuin for Ctrl-R history search (up-arrow left alone).
command -v starship &>/dev/null && eval "$(starship init bash)"
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
# atuin's bash hooks need ble.sh (or bash-preexec) to see each command.
[[ ${BLE_VERSION-} || ${bash_preexec_imported-} ]] && command -v atuin &>/dev/null &&
  eval "$(atuin init bash --disable-up-arrow)"

[[ ${BLE_VERSION-} ]] && ble-attach
