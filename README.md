# gitso

English | [中文](./README.zh-CN.md)

`gitso` is a transparent proxy for the system Git. It forwards every command and argument unchanged, except that `clone` without an explicit destination stores GitHub repositories under:

```text
~/Code/Github.com/<owner>/<repo>
```

## Preview

![GitHub repositories organized by owner](./img/render_en.png)

## Usage

Use normal Git syntax, replacing `git` with `gitso`:

```bash
gitso clone https://github.com/owner/repo.git
gitso clone -b dev --depth 1 git@github.com:owner/repo.git
gitso status --short
gitso pull --ff-only
```

The first command runs the equivalent of:

```bash
git clone https://github.com/owner/repo.git ~/Code/Github.com/owner/repo
```

If a clone destination is supplied, or the remote is not hosted on GitHub, gitso does not modify the command:

```bash
gitso clone https://github.com/owner/repo.git ./custom-dir
gitso clone https://gitlab.com/owner/repo.git
```

Set `GITSO_DEST` to change the organization root:

```bash
GITSO_DEST=~/Projects gitso clone https://github.com/owner/repo.git
```

Options should follow Git's documented clone syntax and appear before the repository URL.

## Design

- Requires the system `git` executable.
- Git handles authentication, credentials, SSH, proxies, LFS, submodules and all command behavior.
- On Unix, gitso replaces itself with Git, preserving terminal interaction, signals and exit codes.
- On Windows, standard input, output, error and the Git exit code are forwarded.

## Installation

Users do not need Go or a gitso source checkout. Only system Git is required at runtime.
Prebuilt binaries cover macOS, Linux and Windows on amd64 and arm64.

### macOS and Linux

```bash
curl -fsSL https://github.com/d3Lap1ace/gitso/releases/latest/download/install.sh | sh
```

Installs to `~/.local/bin/gitso` without sudo. If that directory is not on PATH, run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add that line to `~/.zshrc` (zsh) or `~/.bashrc` (bash) for future terminals.
Installation uses `curl` and either `sha256sum` or `shasum`.

### Windows PowerShell

```powershell
irm https://github.com/d3Lap1ace/gitso/releases/latest/download/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\Programs\gitso` without administrator rights and adds it to your user PATH.
It works in the current PowerShell session; reopen other terminals.

### Install with an agent

Give Codex or another agent with local terminal access this request:

> Install gitso for the current user following https://github.com/d3Lap1ace/gitso.
> Download a prebuilt GitHub Releases binary and verify SHA256. Do not install Go or clone the source.
> Check the OS, architecture, Git and PATH. Run gitso --version and report the install path and release version.

Agents use the same installers; no special agent plugin is needed.

### Choose a version or directory

```bash
curl -fsSL https://github.com/d3Lap1ace/gitso/releases/latest/download/install.sh -o /tmp/gitso-install.sh
GITSO_VERSION=vX.Y.Z GITSO_INSTALL_DIR="$HOME/bin" sh /tmp/gitso-install.sh
```

On Windows, set `$env:GITSO_VERSION = "vX.Y.Z"` and `$env:GITSO_INSTALL_DIR` before running the installer.
Replace `vX.Y.Z` with a published release. Run the installer again to upgrade, or pin an older release to roll back.
SHA256 checks download integrity; it is not a publisher signature.

### Verify and uninstall

```bash
gitso --version
```

This flag is forwarded to Git and prints the **Git version**. The installer separately reports the gitso release and install path.
Use `command -v gitso` on macOS/Linux or `Get-Command gitso` on Windows to check PATH.

To uninstall, delete `gitso` or `gitso.exe` from the install directory. Cloned repositories are unaffected.
Windows users can also remove `%LOCALAPPDATA%\Programs\gitso` from their user PATH.

## Build and release for maintainers

Go is required only for source development:

```bash
go test ./...
go build -o gitso .
sh scripts/build-release.sh
```

The build script produces six platform binaries and `checksums.txt`. Pushing a new `vX.Y.Z` tag triggers
GitHub Actions to run platform checks and publish the binaries, checksums and both installers.
Each installer resolves a single release before downloading and verifying assets. Download or checksum failures preserve the previous install.

**Activation:** Push these changes and create a release containing the new installers before the remote installation commands above can work.
