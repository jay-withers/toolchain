# wsl

Bootstrap a fresh WSL or macOS machine for Azure cloud infrastructure and Kubernetes work.

## Usage

```bash
git clone https://github.com/jay-withers/wsl && cd wsl && bash src/setup.sh
```

## What gets installed

| Category | Tools | Linux | macOS |
| -------- | ----- | ----- | ----- |
| Base | git, curl, wget, jq, yq, unzip | Homebrew | Homebrew |
| Azure | azure-cli | Homebrew | Homebrew |
| Azure | kubelogin | Direct download | Homebrew tap |
| Kubernetes | kubectl, helm, k9s, kubectx | Homebrew | Homebrew |
| Terraform | tfenv, terraform-docs, checkov | Homebrew | Homebrew |
| Terraform | tflint | Direct download | Direct download |
| Dev tools | pre-commit, gitleaks, actionlint, shellcheck, node, commitlint | Homebrew | Homebrew |

## Development

Install pre-commit hooks:

```bash
make install
```

Run linting:

```bash
make lint
```

Test the Linux setup in a local Docker container (requires Docker Desktop):

```bash
make test
```

## Structure

```text
src/
  setup.sh        # entry point — detects OS, delegates to platform script
  linux.sh        # apt prerequisites, Homebrew, direct binary installs
  macos.sh        # Homebrew, macOS-specific packages
  Brewfile        # packages installed on both platforms
  Brewfile.macos  # packages installed on macOS only (kubelogin)
tests/
  test.sh         # runs setup in an Ubuntu 24.04 Docker container
config/
  .pre-commit-config.yaml
  commitlint.config.js
.github/
  workflows/
    pre-commit.yml   # lints all files on PRs to main
    test-install.yml # runs setup.sh on ubuntu-24.04 and macos-15
    tag.yml          # auto-tags on merge to main (semver patch bump)
renovate.json        # automated dependency updates
Makefile
```
