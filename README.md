# SouthWest-NG + KernelSU Next for Redmi Note 7 (lavender)

Linux **4.19** kernel for Xiaomi Redmi Note 7 (`lavender`), based on
[pix106/android_kernel_xiaomi_sdm660_southwest-ng](https://github.com/pix106/android_kernel_xiaomi_sdm660_southwest-ng)
(SouthWest-NG 0.18.0), with [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next)
integrated using **manual syscall hooks**.

This is an unofficial fork. It is not supported by pix106 or KernelSU Next.

Tested on LineageOS 24.0. Kprobe/tracepoint hooks bootlooped on this tree
(Clang CFI + full LTO), so they are **not** used.

Flash at your own risk. Keep a known-good kernel zip (for example SouthWest-NG
0.17.3) on the device and a working recovery (OrangeFox/TWRP) before you try a
new build.

## Features

- SouthWest-NG 0.18.0 (`CONFIG_LOCALVERSION=-SouthWest-NG-0.18.0-ksunext`)
- KernelSU Next **legacy** (`v3.2.0-legacy`, version code 33193)
- Manual hooks (no `CONFIG_KPROBES`, no loadable modules)
- Recovery zip via AnyKernel3 (`Image.gz-dtb`)

The v3.3.0 KernelSU Next manager works with this kernel.

## Flash (prebuilt)

Download the recovery zip from
[Releases](https://github.com/stanley0010/KSU-Next-Kernel-for-LineageOS-24-for-Redmi-Note-7-lavender/releases).
Flash it in OrangeFox/TWRP, reboot to system, then install the
[KernelSU Next manager](https://github.com/KernelSU-Next/KernelSU-Next/releases).

Use only the **manual** zip. A kprobe-based zip for this tree bootloops.

## What this repository contains

- The full kernel tree (SouthWest-NG + the hook/config patches)
- `ksu/` build helpers (`setup.sh`, `build.sh`, `pack.sh`, AnyKernel3 template)
- `README.md` (this file)

KernelSU Next itself is **not** vendored. `./ksu/setup.sh` clones it.
Prebuilt flashable zips belong in **GitHub Releases**, not in git.

## Build (Linux or WSL)

Do **not** compile on native Windows NTFS or `/mnt/c`. `./ksu/build.sh`
refuses to run there. CRLF line endings and 9p/drvfs I/O will break the
4.19 LTO build.

On a native Linux clone:

```bash
git clone https://github.com/stanley0010/KSU-Next-Kernel-for-LineageOS-24-for-Redmi-Note-7-lavender.git
cd KSU-Next-Kernel-for-LineageOS-24-for-Redmi-Note-7-lavender

bash ksu/setup.sh --deps
bash ksu/build.sh --pack
```

On WSL2 (Ubuntu 22.04 + Clang 14), keep the checkout on `/mnt/c` if you
want, but **do not rsync that working tree**. NTFS/9p turns kernel
symlinks into text files and collapses `xt_DSCP.c` / `xt_dscp.c`. Sync
with git onto ext4:

```bash
# from /mnt/c/.../android_kernel_xiaomi_sdm660_southwest-ng
bash ksu/setup.sh --deps
bash ksu/wsl-sync.sh
cd ~/ksu-build/kernel
bash ksu/build.sh --pack
```

`wsl-sync.sh` `git clone`s into `~/ksu-build/kernel` (override with
`KSU_WSL_DEST`) with `core.symlinks=true`, overlays the local hook
patches, and relinks `drivers/kernelsu`. The zip is written to `dist/`
in that copy.

`setup.sh` clones KernelSU-Next (`v3.2.0-legacy` by default) and creates
`drivers/kernelsu` → `KernelSU-Next/kernel`.

The zip is written to `dist/`. Flash it in OrangeFox/TWRP, reboot, then install
the [KernelSU Next manager](https://github.com/KernelSU-Next/KernelSU-Next/releases).

### Options

```bash
JOBS=8 bash ksu/build.sh --clean --pack
DEVICE=lavender ANYKERNEL_DIR=/path/to/AnyKernel3 bash ksu/pack.sh
bash ksu/setup.sh --ksu-ref v3.2.0-legacy
```

Ubuntu 22.04 + Clang 14 is known to work. A full LTO build is about 10–20
minutes on a 16-thread CPU.

## Manual hooks

| File | Function | KernelSU handler |
| --- | --- | --- |
| `fs/exec.c` | `do_execveat_common` | `ksu_handle_execveat` |
| `fs/open.c` | `do_faccessat` | `ksu_handle_faccessat` |
| `fs/read_write.c` | `ksys_read` | `ksu_handle_sys_read` |
| `fs/read_write.c` | `vfs_read` | `ksu_handle_vfs_read` |
| `fs/stat.c` | `newfstatat` (+ compat) | `ksu_handle_stat` |
| `fs/stat.c` | `newfstat` | `ksu_handle_newfstat_ret` |
| `kernel/reboot.c` | `sys_reboot` | `ksu_handle_sys_reboot` |
| `drivers/input/input.c` | `input_handle_event` | `ksu_handle_input_handle_event` |

Also: `path_umount()` in `fs/namespace.c`, `filter_count` on `struct seccomp`.

Defconfig: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`, kprobes and loadable
modules left off.

## Device config

```
make O=out ... vendor/xiaomi/sdm660_defconfig
scripts/kconfig/merge_config.sh -m -O out out/.config \
  arch/arm64/configs/vendor/xiaomi/lavender.config
```

## License

GPL-2.0 WITH Linux-syscall-note, same as the Linux kernel (`COPYING`).
KernelSU Next kernel code is GPL-2.0-only. Distributing a flashable kernel
zip requires corresponding source; this repository is that source.

## Credits

- [pix106 / SouthWest-NG](https://github.com/pix106/android_kernel_xiaomi_sdm660_southwest-ng)
- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next)
- LineageOS Xiaomi SDM660
- [osm0sis AnyKernel3](https://github.com/osm0sis/AnyKernel3)

## Links

- [KernelSU Next: non-GKI integration](https://kernelsu-next.github.io/webpage/pages/how-to-integrate-for-non-gki.html)
- [Upstream SouthWest-NG](https://github.com/pix106/android_kernel_xiaomi_sdm660_southwest-ng)
