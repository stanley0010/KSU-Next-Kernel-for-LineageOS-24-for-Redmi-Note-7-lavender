#!/usr/bin/env bash
# Clone KernelSU-Next, symlink drivers/kernelsu, optional kprobe compat patch.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: ./ksu/setup.sh [--deps] [--ksu-ref <branch-or-tag>]

  --deps       Install Ubuntu/Debian build packages (clang, lld, aarch64 gcc, ...)
  --ksu-ref    KernelSU-Next git ref to checkout (default: v3.2.0-legacy)
EOF
}

KSU_REF="v3.2.0-legacy"
INSTALL_DEPS=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--deps) INSTALL_DEPS=1; shift ;;
		--ksu-ref) KSU_REF="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown argument: $1" >&2; usage; exit 2 ;;
	esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

if [[ "${INSTALL_DEPS}" -eq 1 ]]; then
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "error: --deps currently supports apt-based distros only" >&2
		exit 1
	fi
	export DEBIAN_FRONTEND=noninteractive
	if [[ "$(id -u)" -eq 0 ]]; then
		APT=(apt-get)
	else
		APT=(sudo apt-get)
	fi
	"${APT[@]}" update -y
	"${APT[@]}" install -y --no-install-recommends \
		build-essential bc bison flex libssl-dev libelf-dev \
		clang lld llvm \
		gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
		python3 python-is-python3 \
		git rsync ca-certificates zip unzip \
		device-tree-compiler libncurses-dev
fi

if [[ ! -d KernelSU-Next/.git ]]; then
	echo "==> cloning KernelSU-Next (${KSU_REF})"
	git clone --branch "${KSU_REF}" https://github.com/KernelSU-Next/KernelSU-Next.git KernelSU-Next
else
	echo "==> KernelSU-Next already present"
fi

echo "==> linking drivers/kernelsu"
rm -rf drivers/kernelsu
ln -sfn ../KernelSU-Next/kernel drivers/kernelsu
test -f drivers/kernelsu/Kconfig
test -f drivers/kernelsu/Kbuild

if ! grep -q 'obj-$(CONFIG_KSU)' drivers/Makefile; then
	printf '\nobj-$(CONFIG_KSU)\t\t+= kernelsu/\n' >> drivers/Makefile
	echo "==> added kernelsu to drivers/Makefile"
fi
if ! grep -q 'drivers/kernelsu/Kconfig' drivers/Kconfig; then
	# Insert before the closing endmenu of the Device Drivers menu.
	python3 - <<'PY'
from pathlib import Path
p = Path("drivers/Kconfig")
text = p.read_text()
needle = 'source "drivers/energy_model/Kconfig"\nendmenu\n'
insert = 'source "drivers/energy_model/Kconfig"\nsource "drivers/kernelsu/Kconfig"\nendmenu\n'
if needle not in text:
    raise SystemExit("could not patch drivers/Kconfig (expected energy_model source + endmenu)")
p.write_text(text.replace(needle, insert, 1))
PY
	echo "==> added kernelsu to drivers/Kconfig"
fi

if grep -q '^CONFIG_KSU_KPROBES_HOOK=y' arch/arm64/configs/vendor/xiaomi/sdm660_defconfig \
	arch/arm64/configs/vendor/xiaomi/lavender.config 2>/dev/null; then
	echo "==> applying kprobe compat (ksu_input_hook)"
	python3 "${SCRIPT_DIR}/apply_ksu_compat.py"
else
	echo "==> skipping kprobe compat (manual hooks)"
fi

echo "==> setup complete"
echo "    next: ./ksu/build.sh"
echo "          ./ksu/build.sh --pack"
