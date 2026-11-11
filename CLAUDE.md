# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Bootstrap scripts for a fresh WSL (Ubuntu 24.04) or macOS machine, built on [mise](https://mise.jdx.dev). It replaces the dev-container images for local work: the jay-withers repos are moving off dev containers, so this is how a machine gets its tools. `src/setup.sh` runs `src/linux.sh` (apt: mise, psql, bubblewrap/socat for Claude Code's sandbox) or `src/macos.sh` (Homebrew: mise, libpq), then `src/common.sh`. That script symlinks `src/mise/config.toml` into `~/.config/mise/conf.d/`, runs `mise install`, puts mise shims on PATH in the shell rc files, and verifies every tool.

- **Tools belong in `src/mise/config.toml`**, not in apt or the Brewfile. Use apt or Homebrew only for what mise can't manage (mise itself, psql, OS packages). Renovate's mise manager bumps the versions.
- **Global versus per repo:** the global config holds what every repo assumes. A tool whose version a repo's build or lint depends on also belongs in that repo's `mise.toml`, because that's what CI installs.
- **`kubelogin` must stay `aqua:Azure/kubelogin`.** mise's registry maps the bare name to int128/kubelogin, a different tool.
- **Shims, not `mise activate`,** so non-interactive shells (Claude Code, make, VS Code tasks) resolve per-repo versions. Keep it that way.
- Signing keys for the apt repos are checked against a pinned fingerprint or digest before apt trusts them.
- Docker is deliberately not installed (Docker Desktop's WSL integration provides it); `common.sh` only warns.

## Commands

```bash
make install   # install pre-commit hooks (run once after cloning)
make lint      # run all pre-commit hooks against every file
make test      # run setup.sh in an Ubuntu 24.04 container (bind-mounts the repo: run on the host, not in a dev container)
```

## Commit messages

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/) — enforced by commitlint at commit-msg time. Examples: `feat: add tflint`, `fix: correct arch detection`, `chore: update Brewfile`.

## Pre-commit config

Hooks are in `.pre-commit-config.yaml` at the repo root (pre-commit's default location, so no `--config` flag is needed). The `no-commit-to-branch` hook blocks direct commits to `main`.

## CI

- **ci-pre-commit**: runs all linters on PRs to `main`
- **ci-test-install**: runs `setup.sh` on both `ubuntu-24.04` and `macos-26` on PRs to `main` (only when `src/` files change), with `GITHUB_TOKEN` set so mise's GitHub API calls are not rate-limited
- **cd-tag**: auto-creates a semver tag on every merge to `main` (default bump: patch)
