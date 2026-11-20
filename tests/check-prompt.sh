#!/usr/bin/env bash
# Run after src/setup.sh: checks the interactive-shell setup it wrote loads in
# a fresh interactive shell - zsh everywhere, bash too on Linux - and that zsh
# is the login shell on Linux. shims=0: nothing run on every prompt or
# command goes through a mise shim, which costs a few hundred ms a call.
set -euo pipefail

fail() { echo "  FAIL: $*"; exit 1; }

count() { grep -cxF "$2" "$1" 2>/dev/null || true; }

check_rc() {
  [[ "$(count "$1" "# toolchain: shell")" == "1" ]] || fail "$1 has no single '# toolchain: shell' block"
  [[ "$(count "$1" "# toolchain: prompt")" == "0" ]] || fail "$1 still has the old '# toolchain: prompt' block"
  ! grep -q 'starship init' "$1" || fail "$1 still loads starship itself (old block not migrated)"
}

echo "==> Checking the interactive shells"

check_rc "$HOME/.zshrc"
# shellcheck disable=SC2016  # evaluated by zsh
out="$(zsh -ic 'print -r -- "CHECK starship=${STARSHIP_SHELL:-} suggest=${ZSH_AUTOSUGGEST_STRATEGY:+y} highlight=${ZSH_HIGHLIGHT_VERSION:+y} atuin=${ATUIN_SESSION:+y} zoxide=${+functions[__zoxide_z]} gh=${+_comps[gh]} mise=${+_comps[mise]} az=${+_comps[az]} shims=$( { typeset -f; whence -p atuin zoxide starship; } | grep -c /shims/)"' \
  </dev/null 2>&1 | grep -ao 'CHECK .*' | tail -1 || true)"
[[ "$out" == "CHECK starship=zsh suggest=y highlight=y atuin=y zoxide=1 gh=1 mise=1 az=1 shims=0" ]] ||
  fail "zsh is missing part of its setup: ${out:-no output}"
echo "  ok: zsh (starship, autosuggestions, syntax highlighting, atuin, zoxide, completions)"

if [[ "$(uname)" != "Darwin" ]]; then
  check_rc "$HOME/.bashrc"
  blesh="${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"
  [[ -f "$blesh" ]] || fail "ble.sh not installed at $blesh"
  # ble.sh only loads in a real interactive shell (not `bash -c`), so drive
  # one through a pseudo-terminal, as a terminal ble.sh supports (CI and
  # `docker run` without -t set no usable TERM). The probe is in a file so
  # ble.sh's line editor only has to take one simple line.
  probe="$(mktemp)"
  # shellcheck disable=SC2016  # evaluated by the interactive bash
  printf '%s\n' \
    'shims=$(declare -f | grep -c /shims/)$(type -P atuin zoxide starship | grep -c /shims/)' \
    'echo "CHECK starship=${STARSHIP_SHELL:-} ble=${BLE_VERSION:+y} atuin=${ATUIN_SESSION:+y} zoxide=$(type -t __zoxide_z) completions=$(complete -p gh mise az 2>/dev/null | wc -l) shims=$shims"' \
    > "$probe"
  # ble.sh builds its cache on its first start and drops anything typed
  # meanwhile, so start one shell to warm it up, then type the probe into a
  # second once its prompt has had a moment to come up.
  run_bash() { TERM=xterm-256color LANG=C.UTF-8 timeout 300 script -qec "bash -i" /dev/null 2>&1 | tr -d '\r'; }
  printf 'exit\n' | run_bash >/dev/null || true
  raw="$( { sleep 3; printf 'source %s; exit\n' "$probe"; } | run_bash || true)"
  rm -f "$probe"
  out="$(grep -ao 'CHECK starship=[a-z]* ble=[a-z]* atuin=[a-z]* zoxide=[a-z]* completions=[0-9]* shims=[0-9]*' <<<"$raw" | tail -1 || true)"
  [[ -n "$out" ]] || { echo "  bash output (last 40 lines, control codes stripped):"; sed -E 's/\x1b\[[0-9;?>=]*[a-zA-Z]//g' <<<"$raw" | tail -40; }
  [[ "$out" == "CHECK starship=bash ble=y atuin=y zoxide=function completions=3 shims=00" ]] ||
    fail "bash is missing part of its setup: ${out:-no output}"
  echo "  ok: bash (starship, ble.sh, atuin, zoxide, completions)"

  login="$(getent passwd "$(id -un)" | cut -d: -f7)"
  [[ "${login##*/}" == "zsh" ]] || fail "login shell is $login, not zsh"
  echo "  ok: login shell is $login"
fi
