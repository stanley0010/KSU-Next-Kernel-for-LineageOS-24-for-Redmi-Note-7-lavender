#!/usr/bin/env python3
"""Idempotent KernelSU-Next kprobe-mode fix for 4.19.

selinux_hide.c waits on ksu_input_hook, but that symbol is only defined
when KSU_KPROBES_HOOK is unset. LTO then fails with:

    undefined symbol: ksu_input_hook
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
src = root / "KernelSU-Next" / "kernel" / "runtime" / "ksud_integration.c"
if not src.is_file():
    sys.exit(f"missing {src} (run ./ksu/setup.sh first)")

text = src.read_text()
changed = False

needle1 = (
    "static struct work_struct __maybe_unused stop_input_hook_work;\n"
    "#else\n"
)
insert1 = (
    "static struct work_struct __maybe_unused stop_input_hook_work;\n"
    "bool ksu_input_hook __read_mostly = true;\n"
    "#else\n"
)
if "bool ksu_input_hook __read_mostly = true;\n#else" not in text:
    if needle1 not in text:
        sys.exit("compat pattern 1 not found in ksud_integration.c")
    text = text.replace(needle1, insert1, 1)
    changed = True
    print("defined ksu_input_hook for kprobe mode")
else:
    print("ksu_input_hook already defined in kprobe mode")

needle2 = "\tinput_hook_stopped = true;\n\tbool ret = schedule_work(&stop_input_hook_work);"
insert2 = (
    "\tinput_hook_stopped = true;\n"
    "\tksu_input_hook = false;\n"
    "\tbool ret = schedule_work(&stop_input_hook_work);"
)
if "ksu_input_hook = false;\n\tbool ret = schedule_work(&stop_input_hook_work);" not in text:
    if needle2 not in text:
        sys.exit("compat pattern 2 not found in ksud_integration.c")
    text = text.replace(needle2, insert2, 1)
    changed = True
    print("stop_input_hook now clears ksu_input_hook")
else:
    print("stop_input_hook already clears ksu_input_hook")

if changed:
    src.write_text(text)
    print(f"patched {src}")
else:
    print("no changes needed")
