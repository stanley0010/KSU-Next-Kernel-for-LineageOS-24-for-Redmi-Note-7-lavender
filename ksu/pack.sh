#!/usr/bin/env bash
# Pack out/arch/arm64/boot/Image.gz-dtb into an AnyKernel3 recovery zip.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: ./ksu/pack.sh

Environment:
  ANYKERNEL_DIR   AnyKernel3 template with tools/ (busybox, magiskboot, ak3-core.sh)
  OUT_ZIP         destination zip path
  DEVICE          default: lavender
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEVICE="${DEVICE:-lavender}"
IMG="${ROOT}/out/arch/arm64/boot/Image.gz-dtb"

if [[ ! -f "${IMG}" ]]; then
	echo "error: missing ${IMG}" >&2
	echo "       compile first with ./ksu/build.sh" >&2
	exit 1
fi

resolve_anykernel() {
	local candidate
	for candidate in \
		"${ANYKERNEL_DIR:-}" \
		"${ROOT}/../AnyKernel3-southwest" \
		"${ROOT}/../../AnyKernel3-southwest" \
		"${ROOT}/../AnyKernel3" \
		"${ROOT}/ksu/AnyKernel3"
	do
		[[ -n "${candidate}" ]] || continue
		if [[ -f "${candidate}/anykernel.sh" && -f "${candidate}/tools/ak3-core.sh" ]]; then
			printf '%s\n' "${candidate}"
			return 0
		fi
	done
	return 1
}

if ! AK="$(resolve_anykernel)"; then
	echo "==> cloning osm0sis/AnyKernel3 into ksu/AnyKernel3"
	git clone --depth 1 https://github.com/osm0sis/AnyKernel3.git "${ROOT}/ksu/AnyKernel3"
	AK="${ROOT}/ksu/AnyKernel3"
fi

if [[ -f "${SCRIPT_DIR}/anykernel.sh" ]]; then
	cp -f "${SCRIPT_DIR}/anykernel.sh" "${AK}/anykernel.sh"
fi

echo "==> AnyKernel3: ${AK}"
cp -f "${IMG}" "${AK}/Image.gz-dtb"

DATE="$(date +%Y-%m-%d-%H%M)"
DEFAULT_ZIP="${ROOT}/dist/${DEVICE}-SouthWest-NG-ksunext-${DATE}.zip"
OUT_ZIP="${OUT_ZIP:-${DEFAULT_ZIP}}"
mkdir -p "$(dirname "${OUT_ZIP}")"

python3 - <<PY
import zipfile
from pathlib import Path

ak = Path("${AK}")
out = Path("${OUT_ZIP}")
if out.exists():
    out.unlink()
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in ak.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(ak).as_posix()
        if any(part.startswith(".git") for part in p.relative_to(ak).parts):
            continue
        z.write(p, rel)
names = zipfile.ZipFile(out).namelist()
needed = ("Image.gz-dtb", "anykernel.sh", "META-INF/com/google/android/update-binary")
missing = [n for n in needed if n not in names]
if missing:
    raise SystemExit(f"zip is missing: {missing}")
print(f"wrote {out} ({out.stat().st_size} bytes, {len(names)} entries)")
PY

echo "==> flash this zip in recovery:"
echo "    ${OUT_ZIP}"
