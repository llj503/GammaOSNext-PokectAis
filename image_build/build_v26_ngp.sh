#!/bin/bash
# Assemble the NGP45HT image with 3DS (azahar-nano).
#
# This is the NGP45HT counterpart of build_v24f.sh, which targets Pocket AIS.
# The two boards differ in ways that matter here, so do not mix them up:
#
#   * The launcher is the Leanback TV launcher, not Daijishō. There is no
#     com.magneticchen.daijishou database, so no first-boot platform seed is
#     needed -- gammaos-nano's XMB shell scans /storage/emulated itself and
#     shows a "Nintendo 3DS" system on its own.
#   * The 3DS core and the AdrenoTools hooks go to the boot partition (p3)
#     under /azahar and are staged into /data at boot by azahar-nano-setup.sh.
#     /system has only ~14 MB free and the core alone is 38 MB, so it cannot
#     live there. /vendor is not an option either: a symlink there is rejected
#     by the linker (realpath not in permitted paths).
#   * The 24-bit RGB bus that feeds the RK628 HDMI bridge needs its pinctrl
#     group, and i2c4 must stay disabled -- see the DTB notes in the repo.
#
# Usage:
#   ./build_v26_ngp.sh <base.img> <stage114-dir> [out.img]
#
#   base.img       a v25-or-later NGP45HT image (system/vendor/boot present)
#   stage114-dir   tree with system/bin/{gammaos-nano,drastic-nano,azahar-nano,
#                  nano_shaderc} and system/lib64/libazahar-nano-core.so plus
#                  the 4 hook libs, as extracted from the RG52mini v1.14 ota
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

BASE=${1:?base image}
S=${2:?stage114 directory}
OUT=${3:-ngp-v26.img}

# Partition offsets, 1 MiB units (99 MiB boot FAT at 16, 3400 MiB system at 116).
P3_OFF=16
P4_OFF=116

# debugfs runs against "<file>?offset=<bytes>" for a partition inside a raw image.
P4="$OUT?offset=$((P4_OFF*1048576))"
dbg() { debugfs -w -R "$1" "$P4" >/dev/null 2>&1 || echo "WARN: $1"; }

cp --sparse=always "$BASE" "$OUT"

# ---------- p4 system: nano binaries, AzaharSf, azahar assets ----------
for f in gammaos-nano drastic-nano azahar-nano nano_shaderc; do
    dbg "rm /system/bin/$f"
    dbg "write $S/system/bin/$f /system/bin/$f"
    dbg "sif /system/bin/$f mode 0100755"
    dbg "sif /system/bin/$f uid 0"
    dbg "sif /system/bin/$f gid 2000"
done

dbg "mkdir /system/app/AzaharSf"
dbg "mkdir /system/app/AzaharSf/oat"
dbg "mkdir /system/app/AzaharSf/oat/arm64"
dbg "write $S/system/app/AzaharSf/AzaharSf.apk /system/app/AzaharSf/AzaharSf.apk"
dbg "sif /system/app/AzaharSf/AzaharSf.apk mode 0100644"
dbg "sif /system/app/AzaharSf/AzaharSf.apk uid 0"
dbg "sif /system/app/AzaharSf/AzaharSf.apk gid 0"
dbg "write $S/system/app/AzaharSf/oat/arm64/AzaharSf.odex /system/app/AzaharSf/oat/arm64/AzaharSf.odex"
dbg "sif /system/app/AzaharSf/oat/arm64/AzaharSf.odex mode 0100644"
dbg "write $S/system/app/AzaharSf/oat/arm64/AzaharSf.vdex /system/app/AzaharSf/oat/arm64/AzaharSf.vdex"
dbg "sif /system/app/AzaharSf/oat/arm64/AzaharSf.vdex mode 0100644"

dbg "mkdir /system/etc/azahar-nano"
dbg "write $S/system/etc/azahar-nano/cheats3ds.zip /system/etc/azahar-nano/cheats3ds.zip"
dbg "sif /system/etc/azahar-nano/cheats3ds.zip mode 0100644"

# ---------- p4 system: init glue ----------
dbg "rm /system/etc/init/azahar-nano.rc"
dbg "write $ROOT/image_build/azahar-nano-v26.rc /system/etc/init/azahar-nano.rc"
dbg "sif /system/etc/init/azahar-nano.rc mode 0100644"
dbg "sif /system/etc/init/azahar-nano.rc uid 0"
dbg "sif /system/etc/init/azahar-nano.rc gid 0"

dbg "rm /system/bin/azahar-nano-setup.sh"
dbg "write $ROOT/image_build/azahar-nano-setup.sh /system/bin/azahar-nano-setup.sh"
dbg "sif /system/bin/azahar-nano-setup.sh mode 0100755"
dbg "sif /system/bin/azahar-nano-setup.sh uid 0"
dbg "sif /system/bin/azahar-nano-setup.sh gid 2000"

# ---------- p3 boot FAT: core + AdrenoTools hooks ----------
P3="$OUT@@$((P3_OFF*1048576))"
mdel -i "$P3" ::/rk3562-rg52mini.dtb 2>/dev/null || true
mmd  -i "$P3" ::/azahar 2>/dev/null || true
mcopy -o -i "$P3" "$S/system/lib64/libazahar-nano-core.so" ::/azahar/libazahar-nano-core.so
for f in libhook_impl.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so; do
    mcopy -o -i "$P3" "$S/system/lib64/$f" "::/azahar/$f"
done

echo "== p4 space =="
debugfs -R "stats" "$P4" 2>/dev/null | grep -E "Free blocks|Free inodes"
echo "== p3 /azahar =="
mdir -i "$P3" ::/azahar
echo "== p4 files =="
for f in /system/bin/gammaos-nano /system/bin/azahar-nano /system/bin/azahar-nano-setup.sh \
         /system/app/AzaharSf/AzaharSf.apk /system/etc/init/azahar-nano.rc; do
    printf '%s: ' "$f"
    debugfs -R "stat $f" "$P4" 2>/dev/null | grep -oE "Size: [0-9]+" | head -1
done
echo "== sha256 =="
sha256sum "$OUT"
