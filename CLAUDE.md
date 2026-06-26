# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Bootstrap scripts for provisioning a fresh WSL (Ubuntu 24.04) or macOS machine with Azure/Kubernetes tooling. `src/setup.sh` detects the OS and delegates to `src/linux.sh` or `src/macos.sh`. All Homebrew packages shared between platforms live in `src/Brewfile`; macOS-only packages are in `src/Brewfile.macos`. On Linux, `kubelogin` and `tflint` are installed via direct binary download (not Homebrew).

## Commands

```bash
make install   # install pre-commit hooks (run once after cloning)
make lint      # run all pre-commit hooks against every file
make test      # run setup.sh inside an Ubuntu 24.04 Docker container
```

## Commit messages

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/) — enforced by commitlint at commit-msg time. Examples: `feat: add tflint`, `fix: correct arch detection`, `chore: update Brewfile`.

## Pre-commit config

Hooks are in `config/.pre-commit-config.yaml` (not the repo root). Pass `--config config/.pre-commit-config.yaml` to any `pre-commit` command run manually. The `no-commit-to-branch` hook blocks direct commits to `main`.

## CI

- **pre-commit**: runs all linters on PRs to `main`
- **test-install**: runs `setup.sh` on both `ubuntu-24.04` and `macos-15` on PRs to `main` (only when `src/` files change)
- **tag**: auto-creates a semver tag on every merge to `main` (default bump: patch)
