#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Toolchain setup — mise, Azure, Terraform, Kubernetes"
echo "===================================================="

# shellcheck disable=SC1091
case "$(uname)" in
  Linux)  source "$SCRIPT_DIR/linux.sh" ;;
  Darwin) source "$SCRIPT_DIR/macos.sh" ;;
  *)      echo "Unsupported OS: $(uname)"; exit 1 ;;
esac

# shellcheck source=src/common.sh
source "$SCRIPT_DIR/common.sh"

echo ""
echo "Setup complete. Open a new terminal: it starts zsh, with mise and the shell setup."
echo "(bash is set up too; TOOLCHAIN_LOGIN_SHELL=keep leaves your login shell alone.)"
echo "Then, in each repo: mise trust && mise install"
