#!/usr/bin/env bash
# Run after src/setup.sh: checks the interactive-shell setup it wrote (the
# starship prompt, plus ble.sh on Linux or zsh-autosuggestions on macOS)
# is in place once and loads in a fresh interactive shell.
set -euo pipefail

fail() { echo "  FAIL: $*"; exit 1; }

count() { grep -cF "# toolchain: prompt" "$1" 2>/dev/null || true; }

echo "==> Checking the interactive prompt"
if [[ "$(uname)" == "Darwin" ]]; then
  [[ "$(count ~/.zshrc)" == "1" ]] || fail "$HOME/.zshrc has no single '# toolchain: prompt' block"
  autosuggest="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -f "$autosuggest" ]] || fail "zsh-autosuggestions not installed"
  # shellcheck disable=SC2016  # evaluated by zsh
  out="$(zsh -ic </dev/null 'print -r -- "starship=${STARSHIP_SHELL:-none} ${ZSH_AUTOSUGGEST_STRATEGY:+autosuggest}"' 2>&1 | tail -1)"
  [[ "$out" == "starship=zsh autosuggest" ]] || fail "zsh did not load starship and autosuggestions: $out"
else
  [[ "$(count ~/.bashrc)" == "1" ]] || fail "$HOME/.bashrc has no single '# toolchain: prompt' block"
  blesh="${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"
  [[ -f "$blesh" ]] || fail "ble.sh not installed at $blesh"
  # ble.sh only loads in a real interactive shell (not `bash -c`), so drive
  # one through a pseudo-terminal with the commands on stdin, as a terminal
  # ble.sh supports (CI and `docker run` without -t set no usable TERM).
  # shellcheck disable=SC2016  # evaluated by the interactive bash
  out="$(printf '%s\n' 'echo "CHECK starship=${STARSHIP_SHELL:-} ble=${BLE_VERSION:+loaded}"' exit |
    TERM=xterm-256color LANG=C.UTF-8 script -qec "bash -i" /dev/null 2>&1 | tr -d '\r' | grep -ao 'CHECK starship=[a-z]* ble=[a-z]*' | tail -1 || true)"
  [[ "$out" == "CHECK starship=bash ble=loaded" ]] || fail "bash did not load starship and ble.sh: ${out:-no output}"
fi
echo "  ok: prompt and autosuggestions load"
