#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

BASE=${1:?v24 image (GammaOSCore-NGP45HT-...img)}
SRC=${2:?directory with libazahar-nano-core.so and the 4 hook libs}
OUT=${3:-p3.img}

dd if="$BASE" of="$OUT" bs=1M skip=16 count=99 status=none

mcopy -o -i "$OUT" "$ROOT/p3/extlinux.conf" ::/extlinux/extlinux.conf
mcopy -o -i "$OUT" "$ROOT/p3/rk3562-ro520c.dtb" ::/rk3562-ro520c.dtb
mcopy -o -i "$OUT" "$ROOT/p3/logo.bmp" ::/logo.bmp

mmd -i "$OUT" ::/azahar 2>/dev/null || true
mcopy -o -i "$OUT" "$SRC/libazahar-nano-core.so" ::/azahar/libazahar-nano-core.so
for f in libhook_impl.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so; do
    mcopy -o -i "$OUT" "$SRC/$f" "::/azahar/$f"
done

mdir -i "$OUT" -/ ::/azahar
