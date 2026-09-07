#!/usr/bin/env bash
# Materialize this kernel onto WSL ext4 with real Unix symlinks and
# case-sensitive names (xt_DSCP.c vs xt_dscp.c). Never rsync a Windows
# working tree: NTFS/9p turns symlinks into text files and collapses
# case-colliding paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST="${KSU_WSL_DEST:-${HOME}/ksu-build/kernel}"

if [[ "${SRC}" == "${DEST}" ]]; then
	echo "error: source and destination are the same (${SRC})" >&2
	exit 1
fi
if [[ ! -d "${SRC}/.git" ]]; then
	echo "error: ${SRC} is not a git checkout" >&2
	exit 1
fi

echo "==> src:  ${SRC}"
echo "==> dest: ${DEST}"

if [[ -d "${DEST}/.git" ]]; then
	echo "==> updating existing ext4 clone"
	git -C "${DEST}" -c core.symlinks=true fetch --no-tags origin 2>/dev/null || true
	git -C "${DEST}" -c core.symlinks=true checkout -f HEAD
	git -C "${DEST}" -c core.symlinks=true clean -fd
else
	echo "==> git clone --shared with core.symlinks=true"
	rm -rf "${DEST}"
	# --shared avoids copying the object DB off 9p/NTFS (very slow).
	# The ext4 worktree still gets real symlinks and case-sensitive names.
	git -c core.symlinks=true clone --shared --config core.symlinks=true \
		"${SRC}" "${DEST}"
fi

# KernelSU-Next is a nested repo (not always in the parent index).
if [[ -d "${SRC}/KernelSU-Next/.git" ]]; then
	echo "==> cloning KernelSU-Next (do not rsync it from NTFS)"
	rm -rf "${DEST}/KernelSU-Next"
	git -c core.symlinks=true clone --shared --config core.symlinks=true \
		"${SRC}/KernelSU-Next" "${DEST}/KernelSU-Next"
fi

# Overlay dirty working-tree patches (hooks, build scripts) from Windows.
echo "==> overlaying local patches"
overlay=(
	fs/read_write.c
	fs/stat.c
	README.md
	compile_lavender.sh
	ksu/build.sh
	ksu/pack.sh
	ksu/setup.sh
	ksu/wsl-sync.sh
	ksu/strip_cr.py
	ksu/anykernel.sh
	KernelSU-Next/kernel/runtime/boot_event.c
	KernelSU-Next/kernel/runtime/ksud_integration.c
)
for rel in "${overlay[@]}"; do
	if [[ -f "${SRC}/${rel}" ]]; then
		mkdir -p "$(dirname "${DEST}/${rel}")"
		cp -a "${SRC}/${rel}" "${DEST}/${rel}"
	fi
done

for rel in "${overlay[@]}"; do
	[[ -f "${DEST}/${rel}" ]] || continue
	sed -i 's/\r$//' "${DEST}/${rel}"
done

ln -sfn ../KernelSU-Next/kernel "${DEST}/drivers/kernelsu"
test -f "${DEST}/drivers/kernelsu/Kconfig"
test -h "${DEST}/include/uapi/linux/msm_ion.h"
test -f "${DEST}/net/netfilter/xt_DSCP.c"
test -f "${DEST}/net/netfilter/xt_dscp.c"

echo "==> synced. Build with:"
echo "    cd ${DEST} && bash ksu/build.sh --pack"
