#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "WSL tooling setup — Azure / Kubernetes"
echo "======================================="

# shellcheck disable=SC1091
case "$(uname)" in
  Linux)  source "$SCRIPT_DIR/linux.sh" ;;
  Darwin) source "$SCRIPT_DIR/macos.sh" ;;
  *)      echo "Unsupported OS: $(uname)"; exit 1 ;;
esac

echo ""
echo "Setup complete. Restart your shell to ensure all tools are in PATH."
