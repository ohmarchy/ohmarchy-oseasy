#!/usr/bin/env bash
# Package the patched 7.2 kernel from 25-build-kernel-7.2.sh as
# linux-ohmarchy-oseasy (kernel/pkg/PKGBUILD), which ohmarchy-oseasy-setup
# installs on first boot. Output:
#   $WORK/k72/linux-ohmarchy-oseasy-VER-REL-aarch64.pkg.tar.*
# makepkg runs inside the image's own root (lib/image-chroot.sh), like 27 and 28;
# it needs 30-prepare-image.sh first.
set -euo pipefail
. "$(dirname "$0")/config.sh"
. "$(dirname "$0")/lib/image-chroot.sh"
need losetup mount chroot
cd "$WORK"; . ./image.env
K=$WORK/k72 P=$OHMARCHY_ROOT/kernel/pkg S=$WORK/k72-pkgsrc
[ -s "$K/kver" ] || die "no 7.2 kernel in $K: run 25-build-kernel-7.2.sh first"
KV=$(cat "$K/kver")
grep -qx "_kver=$KV" "$P/PKGBUILD" || die "kernel/pkg/PKGBUILD is not for $KV (_kver)"

rm -rf "$S"; mkdir -p "$S"
cp "$P/PKGBUILD" "$P/build-in-root.sh" "$K/Image" "$S/"
cp "$K/modules-$KV.tar.gz" "$S/modules.tar.gz"
rm -f "$K"/linux-ohmarchy-oseasy-*.pkg.tar.*
image_chroot k72-pkg "$S" "$K" /ohmarchy/build-in-root.sh /ohmarchy-out
rm -rf "$S"
ls -la "$K"/linux-ohmarchy-oseasy-*.pkg.tar.*
