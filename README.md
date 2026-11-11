# toolchain

Bootstrap a fresh WSL or macOS machine for Azure cloud infrastructure and Kubernetes work.

## Usage

```bash
git clone https://github.com/jay-withers/toolchain && cd toolchain && bash src/setup.sh
```

Then open a new shell. In each repo you work on: `mise trust && mise install`.

To update later: `git pull && mise install` in this clone.

## How it works

[mise](https://mise.jdx.dev) installs and pins every tool. Two layers:

- **Global** ([src/mise/config.toml](src/mise/config.toml)): what every jay-withers repo assumes is on PATH. `setup.sh` symlinks it to `~/.config/mise/conf.d/toolchain.toml`, so your own `~/.config/mise/config.toml` is never touched and wins over it.
- **Per repo** (`mise.toml` in the repo): the versions that repo's build and lint depend on. They override the global ones inside that repo, and CI installs exactly those ([workflows v1.26.0+](https://github.com/jay-withers/workflows#toolchain-from-mise)). Until a repo has one, its `.terraform-version` is read instead.

Shells get mise **shims** on PATH (`~/.profile`, `~/.bashrc`, and the zsh equivalents), not `mise activate`. A shim resolves the version for the current directory when the command runs, so non-interactive shells (VS Code tasks, `make`, Claude Code) get the repo's pinned version too.

Renovate keeps the versions in `src/mise/config.toml` current.

## What gets installed

| Tools | From | Linux | macOS |
| ----- | ---- | ----- | ----- |
| az, kubelogin (Azure's), PowerShell | mise | yes | yes |
| gh, jq, yq | mise | yes | yes |
| terraform (default), tflint, terraform-docs, checkov | mise | yes | yes |
| kubectl, helm, k9s, kubectx | mise | yes | yes |
| python, uv, node, pre-commit, shellcheck, actionlint, gitleaks | mise | yes | yes |
| mise | apt (signed repo) / Homebrew | yes | yes |
| psql 18 | apt (PostgreSQL repo) / Homebrew `libpq` | yes | yes |
| bubblewrap, socat (Claude Code sandbox) | apt | yes | not needed |
| Az PowerShell module | pwsh | yes | yes |

**Docker is not installed.** On WSL, install Docker Desktop and turn on WSL integration for the distro (or install Docker Engine yourself). `setup.sh` warns if docker is missing or its daemon is unreachable.

### Moving from the Homebrew setup

Earlier versions installed everything on Linux through Homebrew. Re-running `setup.sh` adds mise alongside it. Delete the old `# toolchain completions` block from `~/.bashrc`/`~/.zshrc` and `brew uninstall` the tools mise now provides, or a stale Homebrew binary can shadow the pinned one.

## Development

Install pre-commit hooks:

```bash
make install
```

Run linting:

```bash
make lint
```

Test the Linux setup in a fresh Ubuntu 24.04 container (requires Docker; `GITHUB_TOKEN` is passed through if set, for mise's GitHub API calls):

```bash
make test
```

## Structure

```text
src/
  setup.sh        # entry point: runs the platform script, then common.sh
  linux.sh        # apt: mise, psql, sandbox prerequisites (signing keys checked)
  macos.sh        # Homebrew: mise, libpq
  common.sh       # links the global mise config, installs tools, shell setup, checks
  Brewfile        # macOS packages
  mise/
    config.toml   # global mise tools, kept current by Renovate
tests/
  test.sh         # runs setup in an Ubuntu 24.04 Docker container
.github/
  workflows/
    ci-pre-commit.yml   # lints all files on PRs to main
    ci-test-install.yml # runs setup.sh on ubuntu-24.04 and macos-26
    ci-codeql.yml       # CodeQL over the workflows
    cd-tag.yml          # auto-tags on merge to main (semver patch bump)
renovate.json           # automated dependency updates
.pre-commit-config.yaml # pre-commit hook definitions
commitlint.config.js    # Conventional Commits config
Makefile
```
