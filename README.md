<!-- purpose: what this repo publishes for RaiGolmi, what each package patches and why, and the licenses it carries
not-here: how RaiGolmi installs and pins the packages (RaiGolmi's common.ps1); a package's build steps (its build.sh and PKGBUILD)
shape: bounded
audited: 3201 2026-10-13
-->
# raigolmi-packages

Patched builds of MSYS2's QEMU and virglrenderer, and an opt-in Venus build, for
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
- **virglrenderer-venus** (`virglrenderer-venus/`): Vulkan for the guest (Venus), for
  RaiGolmi's experimental Venus setting. It is virglrenderer from the
  [winq-emu fork](https://github.com/cmspam/winq-emu-virglrenderer), which ports Venus to
  Windows, at a pinned commit, with patch 003 above and its own `004-venus-failure-log.patch`:
  the fork's in-process render server discards everything virglrenderer logs once Venus
  starts, and most of its failures return without a word; with the patch the server keeps
  writing to the log QEMU's process already has (`VIRGL_LOG_FILE`), and each failure on the
  way from context creation to a blob names itself and its Windows error. Four more repair the
  fork: `005-eventfd-handle.patch` keeps its Windows eventfd as an event's handle value, since
  the CRT cannot wrap an event in an fd and every Venus context failed to create its fence
  eventfd; `006-cursor-top-down.patch` turns every cursor over as virglrenderer 1.3.0 does,
  where the fork left non-`y_0_top` cursors upside down; `007-vrend-no-sync-thread.patch` keeps
  OpenGL's fence sync thread off on Windows, where its second ANGLE context on another thread
  loses the device, while Venus keeps its fence eventfds; `008-dma-buf-shim-needs-importer.patch`
  offers the guest the fork's dma-buf extensions only when the host's OpenGL side can import the
  dma-bufs they produce, which no Windows build with EGL can: with them, Mesa presents every
  Vulkan window as a dma-buf, the compositor's import fails, and its context stops for good,
  freezing the screen. The fork changes the OpenGL path as well,
  so it never replaces the default DLL: the package installs it into `/ucrt64/raigolmi-venus/`
  beside an unchanged copy of the patched QEMU's `qemu-system-x86_64w.exe`, and that copy loads
  the DLL beside it while `/ucrt64/bin` keeps the default one. RaiGolmi starts that copy only
  when the setting is on.

The QEMU and virglrenderer `build.sh` scripts take MSYS2's own PKGBUILD from
[MINGW-packages](https://github.com/msys2/MINGW-packages), apply the patch and a few edits
they list, and build the packages for UCRT64. virglrenderer-venus has a PKGBUILD of its own,
which takes the exe from the QEMU release it names and depends on exactly that QEMU. The `build` workflow runs it on GitHub, by hand,
once per version, and publishes a release named by the version. A version is built once: a
rebuild is a new pkgrel, never a replaced download.

## Licenses

- **QEMU** is GPL-2.0. Each QEMU release here carries the complete source it was built from,
  `mingw-w64-qemu-<version>.src.tar.gz`: the PKGBUILD as built, with the patch, QEMU's own
  tarball and its signature, and the build script.
- **virglrenderer** is MIT; its license travels inside the package, and so does the fork's.
- **virglrenderer-venus** carries QEMU's exe as built for the QEMU release it names; that
  release's source tarball is the exe's complete source.
- The patches and scripts in this repo are MIT ([LICENSE](LICENSE)), except that each patch,
  as a change to its project, is also offered under that project's license.
