#!/usr/bin/env bash
# For tests/test.sh: give the container's ~/.bashrc and ~/.zshrc the
# "# toolchain: prompt" block an earlier setup.sh wrote, so the run checks
# that common.sh migrates it to "# toolchain: shell", plus the old
# "# toolchain: mise" block, whose kubectl/helm completion lines it drops.
set -euo pipefail
# shellcheck disable=SC2016  # written literally, as setup.sh wrote it
printf '%s\n' '' '# toolchain: mise' \
  'command -v mise &>/dev/null && eval "$(mise activate bash --shims)"' \
  'command -v kubectl &>/dev/null && source <(kubectl completion bash)' \
  'command -v helm &>/dev/null && source <(helm completion bash)' \
  '' '# toolchain: prompt' \
  'command -v starship &>/dev/null && eval "$(starship init bash)"' \
  '[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh" ]] && source "${XDG_DATA_HOME:-$HOME/.local/share}/toolchain/blesh/ble.sh"' \
  >> ~/.bashrc
# shellcheck disable=SC2016
printf '%s\n' '# toolchain: mise' \
  'command -v mise &>/dev/null && eval "$(mise activate zsh --shims)"' \
  'autoload -Uz compinit && compinit' \
  'command -v kubectl &>/dev/null && source <(kubectl completion zsh)' \
  'command -v helm &>/dev/null && source <(helm completion zsh)' \
  '' '# toolchain: prompt' \
  'command -v starship &>/dev/null && eval "$(starship init zsh)"' \
  '[[ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"' \
  >> ~/.zshrc
echo "Seeded the old '# toolchain: prompt' block into ~/.bashrc and ~/.zshrc"
