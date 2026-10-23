# gitso

[English](./README.md) | 中文

`gitso` 是系统 Git 的透明代理。除了一种情况外，所有命令和参数都会原样传给 Git：执行没有指定目标目录的 `clone` 时，GitHub 仓库会自动存入：

```text
~/Code/Github.com/<owner>/<repo>
```

## 效果图

![按 GitHub owner 分类存储仓库](./img/render_ch.png)

## 使用方法

按照正常 Git 语法，把 `git` 换成 `gitso`：

```bash
gitso clone https://github.com/owner/repo.git
gitso clone -b dev --depth 1 git@github.com:owner/repo.git
gitso status --short
gitso pull --ff-only
```

第一条命令等价于：

```bash
git clone https://github.com/owner/repo.git ~/Code/Github.com/owner/repo
```

如果明确提供了目标目录，或者仓库不在 GitHub，gitso 不会修改命令：

```bash
gitso clone https://github.com/owner/repo.git ./custom-dir
gitso clone https://gitlab.com/owner/repo.git
```

可以通过 `GITSO_DEST` 修改仓库根目录：

```bash
GITSO_DEST=~/Projects gitso clone https://github.com/owner/repo.git
```

参数应遵循 Git 文档中的 clone 语法，放在仓库 URL 之前。

## 实现原则

- 依赖系统中的 `git` 命令。
- 认证、凭据、SSH、代理、LFS、子模块及所有 Git 行为都由 Git 自己处理。
- Unix 下 gitso 会用 Git 替换自身，完整保留终端交互、信号和退出码。
- Windows 下会转发标准输入、输出、错误和 Git 退出码。

## 安装

用户无需安装 Go，也无需克隆 gitso 源码。运行时只依赖系统 Git。
安装过程使用系统自带的 Shell 与下载工具，支持 macOS / Linux / Windows 的 amd64 和 arm64。

### macOS 和 Linux

```bash
curl -fsSL https://github.com/d3Lap1ace/gitso/releases/latest/download/install.sh | sh
```

默认安装到 `~/.local/bin/gitso`，无需 sudo。如该目录尚未加入 PATH，首次执行：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

将这行加入 `~/.zshrc`（zsh）或 `~/.bashrc`（bash），即可在之后的终端中使用。
安装器需要 `curl` 和 `sha256sum` 或 `shasum`；这些工具只用于安装。

### Windows PowerShell

```powershell
irm https://github.com/d3Lap1ace/gitso/releases/latest/download/install.ps1 | iex
```

默认安装到 `%LOCALAPPDATA%\Programs\gitso`，自动加入用户 PATH，无需管理员权限。
当前 PowerShell 立即可用，其他终端请重新打开。

### 让 Agent 安装

将下面这段话发给 Codex 或其他可操作本机的 Agent：

> 请按 https://github.com/d3Lap1ace/gitso 的安装说明，为当前用户安装 gitso。
> 使用 GitHub Releases 预编译文件并验证 SHA256，不安装 Go，也不克隆源码。
> 检查系统与芯片类型、Git 和 PATH。安装后运行 gitso --version，并告知安装路径和发布版本。

Agent 与手动安装使用同一套安装器，不需要额外的 Agent 插件。

### 指定目录或版本

macOS / Linux：

```bash
curl -fsSL https://github.com/d3Lap1ace/gitso/releases/latest/download/install.sh -o /tmp/gitso-install.sh
GITSO_VERSION=vX.Y.Z GITSO_INSTALL_DIR="$HOME/bin" sh /tmp/gitso-install.sh
```

Windows：先设置 `$env:GITSO_VERSION = "vX.Y.Z"` 和 `$env:GITSO_INSTALL_DIR`，再运行安装命令。
将 `vX.Y.Z` 替换为已发布的实际版本号。重复运行安装器即可升级；指定旧版本即可回退。
SHA256 校验用于检查下载完整性，不代替发布者签名。

### 验证与卸载

```bash
gitso --version
```

gitso 会透明转发这个参数，因此显示的是 **Git 的版本**；安装器会另外输出 gitso 的发布版本与路径。
macOS / Linux 可用 `command -v gitso` 检查 PATH，Windows 可用 `Get-Command gitso`。

卸载时删除安装目录中的 `gitso` 或 `gitso.exe` 即可；已克隆的仓库不受影响。
Windows 用户可同时从用户 PATH 中移除 `%LOCALAPPDATA%\Programs\gitso`。

## 维护者构建和发布

源码开发才需要 Go：

```bash
go test ./...
go build -o gitso .
sh scripts/build-release.sh
```

`build-release.sh` 构建六个平台文件及 `checksums.txt`。推送新的 `vX.Y.Z` 标签后，
GitHub Actions 完成跨平台检查并发布预编译文件、校验文件及两种安装器。
安装器先固定一个发布版本，再下载和校验文件；下载或校验失败时保留原安装。

**启用条件：** 这些改动须先推送到 GitHub，再创建包含新安装器的 Release，上面的远程安装命令才会生效。
