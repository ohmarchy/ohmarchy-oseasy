#!/bin/bash
# build-in-root.sh OUTDIR: makepkg for the PKGBUILD next to this script, with
# Image and modules.tar.gz beside it. Runs as root inside a throwaway copy of the
# Omarchy root (oseasy/26-package-kernel-7.2.sh), so it can install the build
# tools freely; makepkg itself runs as nobody.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: build-in-root.sh OUTDIR}
work=$(mktemp -d /var/tmp/linux-ohmarchy.XXXX)

pacman -Sy --needed --noconfirm base-devel >/dev/null
cp "$here/PKGBUILD" "$here/Image" "$here/modules.tar.gz" "$work/"

cd "$work"
chown -R nobody: "$work"
runuser -u nobody -- env HOME="$work" makepkg -f --noconfirm >/dev/null
mkdir -p "$out"
cp "$work"/linux-ohmarchy-oseasy-*.pkg.tar.* "$out/"
rm -rf "$work"
ls "$out"/linux-ohmarchy-oseasy-*.pkg.tar.*
