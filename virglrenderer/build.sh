#!/usr/bin/env bash
# MSYS2's virglrenderer with 003-d3d11-texture-optional.patch, as a pacman package in $1.
# Without the patch virglrenderer answers EINVAL for a scanout that has no D3D11 texture (the
# boot console, the shutdown screen), QEMU refuses the scanout, and the window says "Display
# output is not active". With it QEMU hands that scanout over as a map, which the launcher
# draws. Writes $1/tag (the release's name) and $1/notes (its source).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$(mkdir -p "$1" && cd "$1" && pwd)
pkg=mingw-w64-ucrt-x86_64-virglrenderer

work=$(mktemp -d)
git clone --depth 1 --filter=blob:none --sparse https://github.com/msys2/MINGW-packages "$work/p"
git -C "$work/p" sparse-checkout set mingw-w64-virglrenderer
cd "$work/p/mingw-w64-virglrenderer"

# The patch is written against 1.3.0; another version is a new reading, not a rebuild.
grep -qx 'pkgver=1.3.0' PKGBUILD || { echo "PKGBUILD is not virglrenderer 1.3.0:" >&2; grep '^pkgver=' PKGBUILD >&2; exit 1; }
cp "$here/003-d3d11-texture-optional.patch" .
sed -i \
  -e 's/^pkgrel=1$/pkgrel=1.1/' \
  -e 's/^        002-no-ioccom.patch)$/        002-no-ioccom.patch\n        003-d3d11-texture-optional.patch)/' \
  -e "/^sha256sums=/,/)\$/ s/)\$/\n            'SKIP')/" \
  -e 's/^    002-no-ioccom.patch$/    002-no-ioccom.patch \\\n    003-d3d11-texture-optional.patch/' \
  PKGBUILD
[ "$(grep -c 003-d3d11-texture-optional.patch PKGBUILD)" = 2 ] && grep -q "^            'SKIP')" PKGBUILD \
  && grep -qx 'pkgrel=1.1' PKGBUILD || { echo "the PKGBUILD edit did not take:" >&2; cat PKGBUILD >&2; exit 1; }

MINGW_ARCH=ucrt64 makepkg-mingw --cleanbuild --syncdeps --force --noconfirm --nocheck

cp "$pkg-1.3.0-1.1-any.pkg.tar.zst" "$out/"
echo "virglrenderer-1.3.0-1.1" > "$out/tag"
cat > "$out/notes" <<EOF
MSYS2's mingw-w64-virglrenderer 1.3.0-1.1 for UCRT64: virglrenderer 1.3.0 (MIT), built from MSYS2's PKGBUILD at https://github.com/msys2/MINGW-packages/tree/$(git -C "$work/p" rev-parse HEAD)/mingw-w64-virglrenderer, with virglrenderer/003-d3d11-texture-optional.patch.
EOF
rm -rf "$work"
