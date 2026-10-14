#!/usr/bin/env bash
# virglrenderer with Venus from the winq-emu fork, and a copy of the patched QEMU's
# qemu-system-x86_64w.exe, as a pacman package in $1 that installs both into
# /ucrt64/raigolmi-venus (PKGBUILD says why there). The fork changes the GL path too, so it
# never replaces the stock DLL in /ucrt64/bin. Writes $1/tag (the release's name) and $1/notes
# (its source).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$(mkdir -p "$1" && cd "$1" && pwd)

work=$(mktemp -d)
# MSYS2's 001-void-param.patch, as its own virglrenderer build applies it.
git clone --depth 1 --filter=blob:none --sparse https://github.com/msys2/MINGW-packages "$work/p"
git -C "$work/p" sparse-checkout set mingw-w64-virglrenderer
mkdir "$work/b"
cp "$here/PKGBUILD" "$work/p/mingw-w64-virglrenderer/001-void-param.patch" \
   "$here/../virglrenderer/003-d3d11-texture-optional.patch" "$here/004-venus-failure-log.patch" \
   "$here/005-eventfd-handle.patch" "$here/006-cursor-top-down.patch" \
   "$here/007-vrend-no-sync-thread.patch" "$here/008-dma-buf-shim-needs-importer.patch" "$work/b/"
cd "$work/b"

# The QEMU it depends on is this repo's release, which no sync database has, so makepkg checks
# no dependencies; what the build itself needs comes from the PKGBUILD's own lists.
MINGW_PREFIX=/ucrt64 MINGW_PACKAGE_PREFIX=mingw-w64-ucrt-x86_64
source PKGBUILD
pacman -S --needed --noconfirm "${makedepends[@]}" $(printf '%s\n' "${depends[@]}" | grep -v -- "-qemu=$_qemu\$")
MINGW_ARCH=ucrt64 makepkg-mingw --cleanbuild --nodeps --force --noconfirm --nocheck

version="$pkgver-$pkgrel"
pkg="mingw-w64-ucrt-x86_64-virglrenderer-venus-$version-any.pkg.tar.zst"
qemu="mingw-w64-ucrt-x86_64-qemu-$_qemu-any.pkg.tar.zst"
# The exe is the patched QEMU's own, unchanged, and the DLL beside it is the fork's.
exe=ucrt64/raigolmi-venus/qemu-system-x86_64w.exe
[ "$(bsdtar -xOf "$pkg" "$exe" | sha256sum)" = "$(bsdtar -xOf "$qemu" ucrt64/bin/qemu-system-x86_64w.exe | sha256sum)" ] \
  || { echo "$exe in $pkg is not the one in $qemu" >&2; exit 1; }
bsdtar -tf "$pkg" | grep -qx ucrt64/raigolmi-venus/libvirglrenderer-1.dll \
  || { echo "$pkg has no ucrt64/raigolmi-venus/libvirglrenderer-1.dll:" >&2; bsdtar -tf "$pkg" >&2; exit 1; }

cp "$pkg" "$out/"
echo "virglrenderer-venus-$version" > "$out/tag"
cat > "$out/notes" <<EOF
mingw-w64-virglrenderer-venus $version for UCRT64, installing into /ucrt64/raigolmi-venus: virglrenderer with Venus (MIT) from https://github.com/cmspam/winq-emu-virglrenderer/tree/$_commit, built with -Dvenus=true -Dvideo=false, with MSYS2's 001-void-param.patch from https://github.com/msys2/MINGW-packages/tree/$(git -C "$work/p" rev-parse HEAD)/mingw-w64-virglrenderer, virglrenderer/003-d3d11-texture-optional.patch and virglrenderer-venus/004-venus-failure-log.patch, 005-eventfd-handle.patch, 006-cursor-top-down.patch, 007-vrend-no-sync-thread.patch and 008-dma-buf-shim-needs-importer.patch; and qemu-system-x86_64w.exe from this repo's release qemu-$_qemu, unchanged (GPL-2.0), whose complete source is that release's mingw-w64-qemu-$_qemu.src.tar.gz.
EOF
rm -rf "$work"
