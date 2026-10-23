#!/bin/sh
# Download a release binary. Go and a source checkout are not required.
set -eu

fail() { printf 'gitso: %s\n' "$*" >&2; exit 1; }
for tool in git curl uname mktemp awk; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done
git --version >/dev/null 2>&1 || fail "git is not working"
if command -v sha256sum >/dev/null 2>&1; then
    checksum() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    checksum() { shasum -a 256 "$1" | awk '{print $1}'; }
else
    fail "sha256sum or shasum is required"
fi

case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) fail "unsupported OS; use install.ps1 on Windows" ;;
esac
case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
esac

download() {
    curl --proto '=https' --proto-redir '=https' --connect-timeout 15 \
        --max-time 120 --retry 3 -fsSL "$@"
}
repo=https://github.com/d3Lap1ace/gitso
version=${GITSO_VERSION:-latest}
if [ "$version" = latest ]; then
    release_url=$(download -I -o /dev/null -w '%{url_effective}' "$repo/releases/latest")
    case "$release_url" in
        "$repo/releases/tag/"*) version=${release_url##*/} ;;
        *) fail "could not resolve latest release; set GITSO_VERSION=vX.Y.Z" ;;
    esac
fi
printf '%s\n' "$version" | LC_ALL=C grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' \
    || fail "invalid GITSO_VERSION: $version"

asset=gitso_${os}_${arch}
install_dir=${GITSO_INSTALL_DIR:-"$HOME/.local/bin"}
case "$install_dir" in
    /*) ;;
    *) fail "GITSO_INSTALL_DIR must be an absolute path" ;;
esac
tmp=$(mktemp -d)
stage=
trap 'rm -rf "$tmp"; if [ -n "$stage" ]; then rm -f "$stage"; fi' 0
trap 'exit 1' HUP INT TERM
base=$repo/releases/download/$version
printf 'Downloading gitso %s for %s/%s...\n' "$version" "$os" "$arch"
download "$base/checksums.txt" -o "$tmp/checksums.txt"
download "$base/$asset" -o "$tmp/$asset"
expected=$(awk -v file="$asset" '$2 == file {print $1; exit}' "$tmp/checksums.txt")
actual=$(checksum "$tmp/$asset")
[ -n "$expected" ] && [ "$actual" = "$expected" ] || fail "checksum verification failed"
chmod 755 "$tmp/$asset"
"$tmp/$asset" --version || fail "downloaded binary could not run with the system git"

mkdir -p "$install_dir"
[ ! -d "$install_dir/gitso" ] || fail "$install_dir/gitso is a directory"
# Stage on the destination filesystem so replacement is atomic.
stage=$(mktemp "$install_dir/.gitso.XXXXXXXX")
cp "$tmp/$asset" "$stage"
chmod 755 "$stage"
mv -f "$stage" "$install_dir/gitso"
stage=
printf 'Installed gitso %s: %s/gitso\n' "$version" "$install_dir"
case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) printf 'Add %s to PATH in your shell settings, then open a new terminal.\n' "$install_dir"
       printf 'For the default directory, run: export PATH="$HOME/.local/bin:$PATH"\n' ;;
esac
