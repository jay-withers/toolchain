# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Bootstrap scripts for a fresh WSL (Ubuntu 24.04) or macOS machine, built on [mise](https://mise.jdx.dev). It replaces the dev-container images for local work: the jay-withers repos are moving off dev containers, so this is how a machine gets its tools. `src/setup.sh` runs `src/linux.sh` (apt: mise, psql, bubblewrap/socat for Claude Code's sandbox, libicu for pwsh, zsh and its plugins; plus ble.sh from a pinned tarball) or `src/macos.sh` (Homebrew: mise, libpq, zsh plugins), then `src/common.sh`. That script symlinks `src/mise/config.toml` into `~/.config/mise/conf.d/`, runs `mise install`, puts mise shims on PATH and the `src/shell/` source line in the shell rc files, makes zsh the login shell, and verifies every tool.

- **Tools belong in `src/mise/config.toml`**, not in apt or the Brewfile. Use apt or Homebrew only for what mise can't manage (mise itself, psql, OS packages). Renovate's mise manager bumps the versions.
- **Global versus per repo:** the global config holds what every repo assumes. A tool whose version a repo's build or lint depends on also belongs in that repo's `mise.toml`, because that's what CI installs.
- **zsh is the default shell; interactive setup lives in `src/shell/rc.{zsh,bash}`**, which the rc files only source (under `# toolchain: shell`), so changes ship with `git pull`. Keep the two files in step, and keep anything that runs per prompt or command off mise's shims (a few hundred ms a call): `tests/check-prompt.sh` fails if a hook references `/shims/`. `common.sh` migrates the older inline `# toolchain: prompt` block and `chsh`es to zsh on Linux (`TOOLCHAIN_LOGIN_SHELL=keep` skips it). ble.sh has no checksum file or Renovate manager: its release URL and digest in `src/linux.sh` are bumped by hand. `tests/check-prompt.sh` checks both shells load everything; `make test` seeds the old block first (`tests/seed-old-rc.sh`) to test the migration.
- **`kubelogin` must stay `aqua:Azure/kubelogin`.** mise's registry maps the bare name to int128/kubelogin, a different tool.
- **Shims, not `mise activate`,** so non-interactive shells (Claude Code, make, VS Code tasks) resolve per-repo versions. Keep it that way.
- Signing keys for the apt repos are checked against a pinned fingerprint or digest before apt trusts them.
- **`common.sh` writes `~/.nodeenvrc`** pinning nodeenv to mise's node. pre-commit skips shims when looking for `node`, so its Node hooks (commitlint) go through nodeenv, whose unpinned "latest" can be a prerelease its version parser crashes on. Don't drop it unless pre-commit learns to use mise's node.
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
- **ci-test-install**: runs `setup.sh` then `tests/check-prompt.sh` on both `ubuntu-24.04` and `macos-26` on PRs to `main` (only when `src/` or `tests/` files change), with `GITHUB_TOKEN` set so mise's GitHub API calls are not rate-limited
- **cd-tag**: auto-creates a semver tag on every merge to `main` (default bump: patch)
