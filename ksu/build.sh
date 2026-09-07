#!/usr/bin/env bash
# Compile Image.gz-dtb for lavender with KernelSU-Next manual hooks.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: ./ksu/build.sh [--pack] [--clean]

  --pack    After a successful build, create the recovery zip
  --clean   Remove out/ before configuring

Environment:
  JOBS                 parallel make jobs (default: nproc)
  DEVICE               fragment name without .config (default: lavender)
  KBUILD_BUILD_USER    (default: ksunext)
  KBUILD_BUILD_HOST    (default: lavender)
EOF
}

DO_PACK=0
DO_CLEAN=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--pack) DO_PACK=1; shift ;;
		--clean) DO_CLEAN=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown argument: $1" >&2; usage; exit 2 ;;
	esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

fstype="$(findmnt -no FSTYPE . 2>/dev/null || true)"
if [[ "${ROOT}" == /mnt/[a-z]/* ]] || [[ "${fstype}" == 9p || "${fstype}" == drvfs || "${fstype}" == fuse.drvfs ]]; then
	echo "error: this tree is on a Windows filesystem (${fstype:-${ROOT}})." >&2
	echo "       Copy it to WSL ext4 first, then build:" >&2
	echo "         bash ksu/wsl-sync.sh" >&2
	echo "         cd \"\${KSU_WSL_DEST:-\$HOME/ksu-build/kernel}\" && bash ksu/build.sh --pack" >&2
	exit 1
fi

DEVICE="${DEVICE:-lavender}"
JOBS="${JOBS:-$(nproc)}"
OUT="${ROOT}/out"
FRAGMENT="arch/arm64/configs/vendor/xiaomi/${DEVICE}.config"

if [[ ! -f "${FRAGMENT}" ]]; then
	echo "error: missing device fragment ${FRAGMENT}" >&2
	exit 1
fi
if [[ ! -f drivers/kernelsu/Kconfig ]]; then
	echo "error: KernelSU-Next is not linked. Run ./ksu/setup.sh first." >&2
	exit 1
fi
if ! command -v clang >/dev/null 2>&1; then
	echo "error: clang not found. On Ubuntu: ./ksu/setup.sh --deps" >&2
	exit 1
fi

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-ksunext}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-${DEVICE}}"

MAKE_OPTS=(
	O="${OUT}"
	ARCH=arm64
	SUBARCH=arm64
	CC=clang
	LD=ld.lld
	AR=llvm-ar
	NM=llvm-nm
	OBJCOPY=llvm-objcopy
	OBJDUMP=llvm-objdump
	STRIP=llvm-strip
	OBJSIZE=llvm-size
	READELF=llvm-readelf
	HOSTCC=clang
	HOSTCXX=clang++
	HOSTAR=llvm-ar
	HOSTLD=ld.lld
	LLVM=1
	LLVM_IAS=1
	CLANG_TRIPLE=aarch64-linux-gnu-
	CROSS_COMPILE=aarch64-linux-gnu-
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-
	CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
)

echo "==> clang: $(clang --version | head -n1)"
echo "==> jobs:  ${JOBS}"
echo "==> out:   ${OUT}"

if [[ "${DO_CLEAN}" -eq 1 ]]; then
	rm -rf "${OUT}"
fi
mkdir -p "${OUT}"

echo "==> merging vendor/xiaomi/sdm660_defconfig + ${DEVICE}.config"
make "${MAKE_OPTS[@]}" vendor/xiaomi/sdm660_defconfig
scripts/kconfig/merge_config.sh -m -O "${OUT}" \
	"${OUT}/.config" \
	"${FRAGMENT}"
make "${MAKE_OPTS[@]}" olddefconfig

echo "==> KernelSU / hook config:"
grep -E 'CONFIG_(KSU|KPROBES|KPROBE_EVENTS|KRETPROBES|MODULES|KSU_KPROBES_HOOK|KSU_MANUAL_HOOK)=' \
	"${OUT}/.config" || true

if ! grep -q '^CONFIG_KSU=y' "${OUT}/.config"; then
	echo "error: CONFIG_KSU did not enable. Check defconfig / Kconfig wiring." >&2
	exit 1
fi
if ! grep -q '^CONFIG_KSU_MANUAL_HOOK=y' "${OUT}/.config"; then
	echo "error: CONFIG_KSU_MANUAL_HOOK did not enable. Manual hooks are required on this tree." >&2
	exit 1
fi
if grep -q '^CONFIG_KSU_KPROBES_HOOK=y' "${OUT}/.config"; then
	echo "error: CONFIG_KSU_KPROBES_HOOK is on; this kernel bootloops with kprobes." >&2
	exit 1
fi
if ! grep -q 'ksu_handle_sys_reboot' kernel/reboot.c; then
	echo "error: kernel/reboot.c is missing ksu_handle_sys_reboot (manual hook)." >&2
	exit 1
fi
if ! grep -q 'ksu_handle_vfs_read' fs/read_write.c; then
	echo "error: fs/read_write.c is missing ksu_handle_vfs_read (init.rc injection)." >&2
	exit 1
fi

echo "==> building Image.gz-dtb"
make "${MAKE_OPTS[@]}" -j"${JOBS}" Image.gz-dtb 2>&1 | tee "${OUT}/build.log"

IMG="${OUT}/arch/arm64/boot/Image.gz-dtb"
if [[ ! -f "${IMG}" ]]; then
	echo "error: ${IMG} was not produced" >&2
	exit 1
fi
ls -lh "${IMG}"
echo "==> kernel image: ${IMG}"

if [[ "${DO_PACK}" -eq 1 ]]; then
	"${SCRIPT_DIR}/pack.sh"
fi
