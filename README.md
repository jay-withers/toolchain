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

**zsh is the default shell.** On Linux, `setup.sh` installs it and makes it your login shell (`chsh`, through sudo); set `TOOLCHAIN_LOGIN_SHELL=keep` to leave yours alone. Both shells get the same interactive setup, from [src/shell/rc.zsh](src/shell/rc.zsh) and [src/shell/rc.bash](src/shell/rc.bash) in this clone, which `~/.zshrc` and `~/.bashrc` source under a `# toolchain: shell` comment, so `git pull` updates it:

- a [starship](https://starship.rs) prompt with the git branch and status, from the lean [src/shell/starship.toml](src/shell/starship.toml) unless you have a `~/.config/starship.toml` (it leaves out the language-version modules, which run tools through mise's shims on every prompt and make it slow)
- grey suggestions as you type, accepted with →: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) in zsh, [ble.sh](https://github.com/akinomyoga/ble.sh) in bash
- [atuin](https://atuin.sh) on Ctrl-R: history search by directory, exit code and time (the up arrow is left alone); `atuin import auto` brings in your old history
- [zoxide](https://github.com/ajeetdsouza/zoxide): `z factory` jumps to the directory you use that matches
- tab completion for gh, mise, az, kubectl and helm; the slow-to-generate ones are cached in `~/.cache/toolchain`

Kept fast: the shell tools' real install directories go first on PATH, so nothing run on every prompt or command goes through a mise shim, and the completion scripts that are slow to generate (gh, az, kubectl, helm) are cached in `~/.cache/toolchain` per binary version.

Moving to zsh: copy your own settings from `~/.bashrc` (exports, PATH, aliases) into `~/.zshrc`. Anything you want to win over the shared setup goes after the `# toolchain: shell` lines. To opt out of the shared setup, delete the line under `# toolchain: shell` but keep the comment, so re-runs leave it out. Machines set up with the earlier `# toolchain: prompt` block are migrated on the next `setup.sh`.

## What gets installed

| Tools | From | Linux | macOS |
| ----- | ---- | ----- | ----- |
| az, kubelogin (Azure's), PowerShell | mise | yes | yes |
| gh, jq, yq | mise | yes | yes |
| terraform (default), tflint, terraform-docs, checkov | mise | yes | yes |
| kubectl, helm, k9s, kubectx | mise | yes | yes |
| python, uv, node, pre-commit, shellcheck, actionlint, gitleaks | mise | yes | yes |
| claude (Claude Code CLI; its self-updater is off, Renovate bumps it) | mise | yes | yes |
| mise | apt (signed repo) / Homebrew | yes | yes |
| psql 18 | apt (PostgreSQL repo) / Homebrew `libpq` | yes | yes |
| bubblewrap, socat (Claude Code sandbox) | apt | yes | not needed |
| starship (prompt), atuin (Ctrl-R history), zoxide (`z`), usage (for mise completions) | mise | yes | yes |
| zsh, zsh-autosuggestions, zsh-syntax-highlighting | apt / Homebrew (zsh is built in) | yes | yes |
| ble.sh (bash autosuggestions) | pinned release tarball | yes | no (zsh) |
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
  shell/
    rc.zsh        # interactive zsh: prompt, suggestions, completions, history
    rc.bash       # the same for bash
    starship.toml # the default prompt config
  Brewfile        # macOS packages
  mise/
    config.toml   # global mise tools, kept current by Renovate
tests/
  test.sh         # runs setup in an Ubuntu 24.04 Docker container
  check-prompt.sh # after setup: both shells load their interactive setup
  seed-old-rc.sh  # before setup in test.sh: the old rc block, to test migration
.github/
  workflows/
    ci-pre-commit.yml   # lints all files on PRs to main
    ci-test-install.yml # runs setup.sh and check-prompt.sh on ubuntu-24.04 and macos-26
    ci-codeql.yml       # CodeQL over the workflows
    cd-tag.yml          # auto-tags on merge to main (semver patch bump)
renovate.json           # automated dependency updates
.pre-commit-config.yaml # pre-commit hook definitions
commitlint.config.js    # Conventional Commits config
Makefile
```
