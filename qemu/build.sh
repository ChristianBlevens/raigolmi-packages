#!/usr/bin/env bash
# MSYS2's QEMU with 004-file-win32-discard.patch, built for x86_64 only, as pacman packages in
# $1. Without the patch QEMU's Windows file driver has no discard, so what the guest frees
# stays in the disk image and the file only grows; with it the image is sparse and a discard
# releases its range in place. Writes $1/tag (the release's name) and $1/notes (its source).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$(mkdir -p "$1" && cd "$1" && pwd)

work=$(mktemp -d)
git clone --depth 1 --filter=blob:none --sparse https://github.com/msys2/MINGW-packages "$work/p"
git -C "$work/p" sparse-checkout set mingw-w64-qemu
cd "$work/p/mingw-w64-qemu"

# The patch is written against 11.1.1; another version is a new reading, not a rebuild.
grep -qx '_base_ver="11.1.1"' PKGBUILD || { echo "PKGBUILD is not QEMU 11.1.1:" >&2; grep '^_base_ver=' PKGBUILD >&2; exit 1; }
rel=$(sed -n 's/^pkgrel=\([0-9]*\)$/\1/p' PKGBUILD)
[ -n "$rel" ] || { echo "PKGBUILD has no plain pkgrel" >&2; exit 1; }
cp "$here/004-file-win32-discard.patch" .
# One emulator (the PKGBUILD's own "faster testing" line), the patch applied, and the TCG
# plugins, which that build may not produce and nothing here uses, left out of the package.
sed -i \
  -e "s/^pkgrel=$rel\$/pkgrel=$rel.1/" \
  -e 's/^  msys2.examples.tests.sh$/  msys2.examples.tests.sh\n  004-file-win32-discard.patch/' \
  -e "/^sha256sums=/,/)\$/ s/)\$/\n            'SKIP')/" \
  -e 's/^  #apply_patch_with_msg whpx.\$I.patch$/  apply_patch_with_msg 004-file-win32-discard.patch/' \
  -e 's/^  #CONFIGURE_OPTS="--target-list=x86_64-softmmu"$/  CONFIGURE_OPTS="--target-list=x86_64-softmmu"/' \
  -e '/^  # Install tcg plugins to lib\/qemu\/plugins$/d' \
  -e '/^  mkdir -pv lib\/qemu\/plugins\/test lib\/qemu\/plugins\/contrib$/d' \
  -e '/^  install -t lib\/qemu\/plugins\//d' \
  PKGBUILD
[ "$(grep -c 004-file-win32-discard.patch PKGBUILD)" = 2 ] \
  && grep -qx '  CONFIGURE_OPTS="--target-list=x86_64-softmmu"' PKGBUILD \
  && grep -qx "pkgrel=$rel.1" PKGBUILD && ! grep -q 'lib/qemu/plugins' PKGBUILD \
  || { echo "the PKGBUILD edit did not take:" >&2; cat PKGBUILD >&2; exit 1; }

# --skippgpcheck: the tarball's signature needs its signer's key in this keyring; the
# tarball's sha256 in the PKGBUILD still pins it.
MINGW_ARCH=ucrt64 makepkg-mingw --cleanbuild --syncdeps --force --noconfirm --nocheck --skippgpcheck

version="11.1.1-$rel.1"
for pkg in qemu qemu-common qemu-guest-agent qemu-image-util; do
  cp "mingw-w64-ucrt-x86_64-$pkg-$version-any.pkg.tar.zst" "$out/"
done
echo "qemu-$version" > "$out/tag"
cat > "$out/notes" <<EOF
MSYS2's mingw-w64-qemu $version for UCRT64: QEMU 11.1.1 (source: https://download.qemu.org/qemu-11.1.1.tar.xz, GPL-2.0), built from MSYS2's PKGBUILD at https://github.com/msys2/MINGW-packages/tree/$(git -C "$work/p" rev-parse HEAD)/mingw-w64-qemu, with qemu/004-file-win32-discard.patch and the edits in qemu/build.sh.
EOF
rm -rf "$work"
