#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed or not in PATH. Install Docker Desktop and try again."
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Error: Docker is not running. Start Docker Desktop and try again."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running setup.sh in Ubuntu 24.04 container..."
echo "Repo mounted at /wsl"
echo ""

docker run --rm -it \
  --volume "${REPO_ROOT}:/wsl" \
  ubuntu:24.04 \
  bash -c "cd /wsl && bash scripts/setup.sh"
