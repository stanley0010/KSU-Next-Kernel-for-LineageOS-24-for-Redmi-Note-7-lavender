#!/usr/bin/env python3
"""Strip CR from text files. Used after copying a Windows checkout onto ext4."""
from pathlib import Path
import sys

SKIP_PARTS = {".git", "out", "dist"}
root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
n = 0
for p in root.rglob("*"):
    if not p.is_file():
        continue
    if any(part in SKIP_PARTS for part in p.parts):
        continue
    try:
        data = p.read_bytes()
    except OSError:
        continue
    if b"\0" in data[:4096]:
        continue
    if b"\r" not in data:
        continue
    p.write_bytes(data.replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
    n += 1
print(f"stripped CR from {n} files under {root}")
