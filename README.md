# gitso

English | [中文](./README.zh-CN.md)

`gitso` wraps the system Git and organizes GitHub clones by owner. For commands in the form `gitso clone [options] <github-url>`, it adds a destination under:

```text
~/Code/Github.com/<owner>/<repo>
```

A GitHub URL supplied as the only argument is shorthand for `gitso clone <github-url>`. All other commands and arguments are passed through to Git. Authentication and repository operations use your existing Git setup.

## Preview

![GitHub repositories organized by owner](./img/render_en.png)

## Usage

Clone a GitHub repository directly:

```bash
gitso git@github.com:NousResearch/hermes-agent.git
```

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

This stores the repository at `~/Projects/owner/repo`. To keep this setting across commands, add `export GITSO_DEST="$HOME/Projects"` to your shell configuration.

### Automatic destination rules

- `clone` must be the first argument, and the repository URL must be the last argument. Put clone options before the URL.
- Supported GitHub URL forms include `https://github.com/owner/repo.git`, `git@github.com:owner/repo.git` and `ssh://git@github.com/owner/repo.git`. The `.git` suffix is optional.
- Explicit destinations, non-GitHub remotes and GitHub Enterprise hosts are passed through to Git.
- Git global options before `clone`, such as `gitso -C ~/Projects clone <url>`, are passed through without adding an automatic destination.
- Parent directories are created automatically. If the destination already exists, Git determines whether cloning can proceed.

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

On Windows:

```powershell
$env:GITSO_VERSION = "vX.Y.Z"
$env:GITSO_INSTALL_DIR = Join-Path $env:LOCALAPPDATA "Programs\gitso"
irm https://github.com/d3Lap1ace/gitso/releases/latest/download/install.ps1 | iex
```

Replace `vX.Y.Z` with a published release. Run the installer again to upgrade, or pin an older release to roll back.
SHA256 checks download integrity; it is not a publisher signature.

| Variable | Purpose | Default |
| --- | --- | --- |
| `GITSO_DEST` | Root directory for automatically organized clones | `~/Code/Github.com` |
| `GITSO_VERSION` | Release binary selected by the installer | `latest` |
| `GITSO_INSTALL_DIR` | Absolute directory where the installer places the executable | `~/.local/bin` on macOS/Linux; `%LOCALAPPDATA%\Programs\gitso` on Windows |

`GITSO_DEST` is read when running gitso; the other two variables are used only during installation.

### Verify and uninstall

```bash
gitso --version
```

This flag is forwarded to Git and prints the **Git version**. The installer separately reports the gitso release and install path.
Use `command -v gitso` on macOS/Linux or `Get-Command gitso` on Windows to check PATH.

To uninstall, delete `gitso` or `gitso.exe` from the install directory. Cloned repositories are unaffected.
Windows users can also remove `%LOCALAPPDATA%\Programs\gitso` from their user PATH.

## Build and release for maintainers

Source development requires Go 1.24.0 or newer; `go.mod` specifies the Go 1.24.6 toolchain. Build and run the existing Go tests from the repository root:

```bash
go test ./...
go build -o gitso .
```

On macOS/Linux, run the offline installer tests with Python 3:

```bash
python3 -m unittest discover -s tests -v
```

On Windows, build the installer fixture and run the PowerShell tests:

```powershell
go build -o "$env:TEMP\gitso-fixture.exe" .
./tests/install_windows.ps1 -Fixture "$env:TEMP\gitso-fixture.exe"
```

Build release assets on macOS/Linux:

```bash
sh scripts/build-release.sh
```

The build script produces six platform binaries and `checksums.txt` in `dist/release/`.
Pushing a new `vX.Y.Z` tag triggers GitHub Actions to run Go and installer checks on macOS, Linux and Windows, then publish the binaries, checksums and both installers.
Each installer resolves a single release before downloading and verifying assets. Download or checksum failures preserve the previous install.

The remote installation commands require a published GitHub Release containing the installers, platform binaries and `checksums.txt`.

## License

[MIT](./LICENSE)
