#!/usr/bin/env bash
# MSYS2's QEMU with 004-file-win32-discard.patch, 005-whpx-cpuid-xsave-size.patch,
# 006-dsound-capture-only-with-input.patch and 007-virgl-map-blob-off-main-loop.patch, built for
# x86_64 only, as pacman packages in $1.
# Without 004 QEMU's Windows file driver has no discard, so what the guest frees stays in the
# disk image and the file only grows; with it the image is sparse and a discard releases its
# range in place. Without 005 a guest on a CPU with no XSAVEC reads an XSAVE size that disagrees
# with its XCR0, and Linux 7.2 then fails its first exec. Without 006 DirectSound opens the
# default recording device even with in.voices=0, and QEMU does not start on a PC with none.
# Without 007 mapping a Venus blob holds QEMU's main loop for tens of milliseconds, and every
# timer on it, the sound card's among them, stops meanwhile. Writes $1/tag (the release's name)
# and $1/notes (its source).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$(mkdir -p "$1" && cd "$1" && pwd)

# The MINGW-packages commit whose PKGBUILD is QEMU 11.1.1, the version the patches are written
# against.
msys2=d7bc16f1824d59e57a99c887bfd7035afa12bf03
work=$(mktemp -d)
git init -q "$work/p"
git -C "$work/p" remote add origin https://github.com/msys2/MINGW-packages
git -C "$work/p" sparse-checkout set mingw-w64-qemu
git -C "$work/p" fetch -q --depth 1 --filter=blob:none origin "$msys2"
git -C "$work/p" checkout -q FETCH_HEAD
cd "$work/p/mingw-w64-qemu"

# The patch is written against 11.1.1; another version is a new reading, not a rebuild.
grep -qx '_base_ver="11.1.1"' PKGBUILD || { echo "PKGBUILD is not QEMU 11.1.1:" >&2; grep '^_base_ver=' PKGBUILD >&2; exit 1; }
rel=$(sed -n 's/^pkgrel=\([0-9]*\)$/\1/p' PKGBUILD)
[ -n "$rel" ] || { echo "PKGBUILD has no plain pkgrel" >&2; exit 1; }
cp "$here/004-file-win32-discard.patch" "$here/005-whpx-cpuid-xsave-size.patch" \
   "$here/006-dsound-capture-only-with-input.patch" "$here/007-virgl-map-blob-off-main-loop.patch" .
# One emulator (the PKGBUILD's own "faster testing" line), the patches applied, and the TCG
# plugins, which that build may not produce and nothing here uses, left out of the package.
sed -i \
  -e "s/^pkgrel=$rel\$/pkgrel=$rel.4/" \
  -e 's/^  msys2.examples.tests.sh$/  msys2.examples.tests.sh\n  004-file-win32-discard.patch\n  005-whpx-cpuid-xsave-size.patch\n  006-dsound-capture-only-with-input.patch\n  007-virgl-map-blob-off-main-loop.patch/' \
  -e "/^sha256sums=/,/)\$/ s/)\$/\n            'SKIP'\n            'SKIP'\n            'SKIP'\n            'SKIP')/" \
  -e 's/^  #apply_patch_with_msg whpx.\$I.patch$/  apply_patch_with_msg 004-file-win32-discard.patch 005-whpx-cpuid-xsave-size.patch 006-dsound-capture-only-with-input.patch 007-virgl-map-blob-off-main-loop.patch/' \
  -e 's/^  #CONFIGURE_OPTS="--target-list=x86_64-softmmu"$/  CONFIGURE_OPTS="--target-list=x86_64-softmmu"/' \
  -e '/^  # Install tcg plugins to lib\/qemu\/plugins$/d' \
  -e '/^  mkdir -pv lib\/qemu\/plugins\/test lib\/qemu\/plugins\/contrib$/d' \
  -e '/^  install -t lib\/qemu\/plugins\//d' \
  PKGBUILD
[ "$(grep -c 004-file-win32-discard.patch PKGBUILD)" = 2 ] && [ "$(grep -c 005-whpx-cpuid-xsave-size.patch PKGBUILD)" = 2 ] \
  && [ "$(grep -c 006-dsound-capture-only-with-input.patch PKGBUILD)" = 2 ] \
  && [ "$(grep -c 007-virgl-map-blob-off-main-loop.patch PKGBUILD)" = 2 ] \
  && grep -qx '  CONFIGURE_OPTS="--target-list=x86_64-softmmu"' PKGBUILD \
  && grep -qx "pkgrel=$rel.4" PKGBUILD && ! grep -q 'lib/qemu/plugins' PKGBUILD \
  || { echo "the PKGBUILD edit did not take:" >&2; cat PKGBUILD >&2; exit 1; }

# --skippgpcheck: the tarball's signature needs its signer's key in this keyring; the
# tarball's sha256 in the PKGBUILD still pins it.
MINGW_ARCH=ucrt64 makepkg-mingw --cleanbuild --syncdeps --force --noconfirm --nocheck --skippgpcheck

version="11.1.1-$rel.4"
for pkg in qemu qemu-common qemu-guest-agent qemu-image-util; do
  cp "mingw-w64-ucrt-x86_64-$pkg-$version-any.pkg.tar.zst" "$out/"
done
# The complete corresponding source the packages are built from, as GPL-2.0 asks of whoever
# hands out the binaries: the edited PKGBUILD with every file it names, QEMU's own tarball and
# its signature among them, and this script.
cp "$here/build.sh" raigolmi-build.sh
tar --exclude=./src --exclude=./pkg --exclude='./*.pkg.tar.zst' --exclude='./*.log' \
  --owner=0 --group=0 -czf "$out/mingw-w64-qemu-$version.src.tar.gz" \
  --transform 's,^\.,mingw-w64-qemu,' .
echo "qemu-$version" > "$out/tag"
cat > "$out/notes" <<EOF
MSYS2's mingw-w64-qemu $version for UCRT64: QEMU 11.1.1 (source: https://download.qemu.org/qemu-11.1.1.tar.xz, GPL-2.0), built from MSYS2's PKGBUILD at https://github.com/msys2/MINGW-packages/tree/$(git -C "$work/p" rev-parse HEAD)/mingw-w64-qemu, with qemu/004-file-win32-discard.patch, qemu/005-whpx-cpuid-xsave-size.patch, qemu/006-dsound-capture-only-with-input.patch, qemu/007-virgl-map-blob-off-main-loop.patch and the edits in qemu/build.sh. The complete source it was built from is attached: mingw-w64-qemu-$version.src.tar.gz.
EOF
rm -rf "$work"
