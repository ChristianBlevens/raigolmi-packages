# raigolmi-packages

Patched builds of MSYS2's QEMU and virglrenderer for
[RaiGolmi](https://github.com/ChristianBlevens/RaiGolmi), whose Windows app runs its VM with
them. RaiGolmi's `setup.bat` downloads them from this repo's releases, checks each file
against a SHA-256 pinned in RaiGolmi's `common.ps1`, and installs them into MSYS2 over the
stock packages. You don't need to touch this repo to use RaiGolmi.

## What's patched, and why

- **QEMU** (`qemu/004-file-win32-discard.patch`): QEMU's Windows file driver has no discard,
  so whatever the guest frees stays in the disk image and the file only ever grows. With the
  patch the image is sparse, and a discard gives its range back in place.
- **virglrenderer** (`virglrenderer/003-d3d11-texture-optional.patch`): without it,
  virglrenderer refuses a scanout that has no D3D11 texture, like the boot console and the
  shutdown screen, and the window says "Display output is not active". With it QEMU hands
  that scanout over as a plain map, which RaiGolmi's window draws.

Each `build.sh` takes MSYS2's own PKGBUILD from
[MINGW-packages](https://github.com/msys2/MINGW-packages), applies the patch and a few edits
it lists, and builds the packages for UCRT64. The `build` workflow runs it on GitHub, by hand,
once per version, and publishes a release named by the version. A version is built once: a
rebuild is a new pkgrel, never a replaced download.

## Licenses

- **QEMU** is GPL-2.0. Each QEMU release here carries the complete source it was built from,
  `mingw-w64-qemu-<version>.src.tar.gz`: the PKGBUILD as built, with the patch, QEMU's own
  tarball and its signature, and the build script.
- **virglrenderer** is MIT; its license travels inside the package.
- The patches and scripts in this repo are MIT ([LICENSE](LICENSE)), except that each patch,
  as a change to its project, is also offered under that project's license.
