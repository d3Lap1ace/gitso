#!/bin/sh
# Build stable asset names consumed by both installers.
set -eu
out=${1:-dist/release}
mkdir -p "$out"
for os in darwin linux windows; do
    for arch in amd64 arm64; do
        asset=gitso_${os}_${arch}
        [ "$os" != windows ] || asset=$asset.exe
        CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath -ldflags='-s -w' -o "$out/$asset" .
    done
done
(
    cd "$out"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum gitso_* > checksums.txt
    else
        shasum -a 256 gitso_* > checksums.txt
    fi
)
