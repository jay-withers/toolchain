# shellcheck shell=bash disable=SC1090,SC1091,SC2034  # zsh read as bash: computed sources, zsh's own variables
# Interactive zsh, the default shell. Sourced from ~/.zshrc by the line under
# "# toolchain: shell" that src/common.sh writes, after the "# toolchain: mise"
# block has run compinit. A file in this clone rather than lines in your rc,
# so `git pull` updates it. Every line is a no-op where its tool is missing.
# (shellcheck has no zsh mode; it reads this as bash, hence the disables.)

[[ -o interactive ]] || return 0

# History: zsh keeps none on disk unless told to. Shared between open shells.
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
(( HISTSIZE >= 50000 )) || HISTSIZE=50000
(( SAVEHIST >= 50000 )) || SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_reduce_blanks hist_ignore_space
setopt auto_cd interactive_comments
# Case-insensitive completion, and a menu you can move through with the arrows.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

# Calls through a mise shim cost a few hundred ms, and atuin and zoxide run on
# every command and cd. So resolve the real install directories once, in one
# call, and put the shell tools' first on PATH (no repo pins those, so this
# never shadows a per-repo version). gh's and az's feed the completion cache.
_toolchain_paths="$(command -v mise &>/dev/null && mise bin-paths starship atuin zoxide usage gh pypi:azure-cli </dev/null 2>/dev/null)"
_toolchain_dir() { grep -m1 "/installs/$1/" <<<"$_toolchain_paths"; }
for _toolchain_tool in usage zoxide atuin starship; do
  _toolchain_d="$(_toolchain_dir "$_toolchain_tool")"
  [[ -n $_toolchain_d && :$PATH: != *":$_toolchain_d:"* ]] && PATH="$_toolchain_d:$PATH"
done

# Generating gh's and az's completion scripts takes most of a second, so each
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

# Completions kubectl and helm lack in the "# toolchain: mise" block. mise's
# needs `usage`, which the global mise config installs, and is quick enough to
# run each time.
_toolchain_cached gh.zsh "$_toolchain_gh" "$_toolchain_gh" completion -s zsh
command -v mise &>/dev/null && command -v usage &>/dev/null && source <(mise completion zsh)
# az's is argcomplete's bash one, through zsh's bash-completion emulation.
if [[ -x $_toolchain_az_complete ]]; then
  autoload -U +X bashcompinit && bashcompinit
  _toolchain_cached az.zsh "$_toolchain_az_complete" "$_toolchain_az_complete" az
fi
unset -f _toolchain_cached _toolchain_dir
unset _toolchain_paths _toolchain_tool _toolchain_d _toolchain_gh _toolchain_az _toolchain_az_complete

# toolchain's lean starship config, unless you have your own.
[[ -z ${STARSHIP_CONFIG-} && ! -f $HOME/.config/starship.toml ]] &&
  export STARSHIP_CONFIG="${0%/*}/starship.toml"

# Prompt with the git branch and status; `z <part of a path>` to jump to a
# directory you use; atuin for Ctrl-R history search (up-arrow left alone).
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# Grey suggestions as you type (→ accepts), then syntax highlighting, which
# has to be sourced last. apt puts them in /usr/share, Homebrew in its prefix.
for _toolchain_plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  for _toolchain_dir in /usr/share "${HOMEBREW_PREFIX:-/opt/homebrew}/share" /usr/local/share; do
    if [[ -f $_toolchain_dir/$_toolchain_plugin/$_toolchain_plugin.zsh ]]; then
      source "$_toolchain_dir/$_toolchain_plugin/$_toolchain_plugin.zsh"
      break
    fi
  done
done
unset _toolchain_plugin _toolchain_dir
