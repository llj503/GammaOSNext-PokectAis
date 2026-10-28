#!/usr/bin/env python3
"""Patch the NGP45HT RK30BOARD audio HAL to use HP for the speaker path.

The Pocket AIS speaker is connected to the RK817 HP output and an external
amplifier, not the SPK output.  This HAL ignores mixer_paths.xml and uses a
compiled-in default route table, so the independent string "SPK" in the
playback path table must be changed to "HP".

Usage:
    python3 patch_audio_hal.py /path/to/vendor
    python3 patch_audio_hal.py --check /path/to/vendor

The vendor root must contain:
    lib/hw/audio.primary.rk30board.so
    lib64/hw/audio.primary.rk30board.so
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

TARGETS = (
    (
        "lib/hw/audio.primary.rk30board.so",
        0xA576,
        "e3b529c9be24b50b7d87e022412541aaf5c5f57d0acd975d84f528f6eb885b6e",
        "01817b644c40ba8eb3a720ce50f2a08b78c5803a5e9144d60a3435f6d6b4b01d",
    ),
    (
        "lib64/hw/audio.primary.rk30board.so",
        0xC37B,
        "8d0b238478ef105fb98a1666507ef712204f81217efb906808e4a26e3eb41ef6",
        "e327017b3e0414b71b859e0d9e3c972f433e3d789d2ae5ae65fb3b8617834728",
    ),
)

OLD = b"SPK"
NEW = b"HP\x00"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def patch_one(root: Path, rel: str, offset: int, before: str, after: str, check: bool) -> bool:
    path = root / rel
    if not path.is_file():
        print(f"MISSING {rel}")
        return False

    data = path.read_bytes()
    digest = sha256(data)

    if digest == after:
        print(f"OK      {rel} (already patched)")
        return True

    if digest != before:
        print(f"ERROR   {rel}: unexpected SHA-256 {digest}")
        print(f"        expected {before}")
        return False

    if data[offset : offset + len(OLD)] != OLD:
        print(f"ERROR   {rel}: bytes at 0x{offset:X} are not {OLD!r}")
        return False

    if check:
        print(f"PENDING {rel}: patch available at 0x{offset:X}")
        return True

    with path.open("r+b") as f:
        f.seek(offset)
        f.write(NEW)

    patched_digest = sha256(path.read_bytes())
    if patched_digest != after:
        print(f"ERROR   {rel}: post-patch SHA-256 {patched_digest}, expected {after}")
        return False

    print(f"PATCHED {rel} at 0x{offset:X}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vendor_root", type=Path, help="vendor root (contains lib/ and lib64/)")
    parser.add_argument("--check", action="store_true", help="verify only, do not write")
    args = parser.parse_args()

    if not args.vendor_root.is_dir():
        print(f"ERROR: not a directory: {args.vendor_root}", file=sys.stderr)
        return 2

    ok = True
    for rel, offset, before, after in TARGETS:
        ok = patch_one(args.vendor_root, rel, offset, before, after, args.check) and ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
