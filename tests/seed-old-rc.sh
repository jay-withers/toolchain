#!/usr/bin/env bash
# For tests/test.sh: give the container's ~/.bashrc and ~/.zshrc the
# "# toolchain: prompt" block an earlier setup.sh wrote, so the run checks
# that common.sh migrates it to "# toolchain: shell".
set -euo pipefail
# shellcheck disable=SC2016  # written literally, as setup.sh wrote it
printf '%s\n' '' '# toolchain: prompt' \
  'command -v starship &>/dev/null && eval "$(starship init bash)"' \
  '[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh" ]] && source "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"' \
  >> ~/.bashrc
# shellcheck disable=SC2016
printf '%s\n' '# toolchain: prompt' \
  'command -v starship &>/dev/null && eval "$(starship init zsh)"' \
  '[[ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"' \
  >> ~/.zshrc
echo "Seeded the old '# toolchain: prompt' block into ~/.bashrc and ~/.zshrc"
