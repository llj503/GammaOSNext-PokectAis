#!/bin/bash
set -euo pipefail
G=/mnt/f/pocketAis/gammaos
S=$G/stage114
IMG=$G/p4_new.img
cp -f $G/v24_p4.img $IMG
dbg() { debugfs -w -R "$1" "$IMG" >/dev/null 2>&1 || echo "WARN: $1"; }

# nano shell + emulators
for f in gammaos-nano drastic-nano; do
  dbg "rm /system/bin/$f"
  dbg "write $S/system/bin/$f /system/bin/$f"
  dbg "sif /system/bin/$f mode 0100755"
done
for f in azahar-nano nano_shaderc; do
  dbg "rm /system/bin/$f"
  dbg "write $S/system/bin/$f /system/bin/$f"
  dbg "sif /system/bin/$f mode 0100755"
done

# 3DS launcher app + odex
dbg "mkdir /system/app/AzaharSf"
dbg "mkdir /system/app/AzaharSf/oat"
dbg "mkdir /system/app/AzaharSf/oat/arm64"
dbg "write $S/system/app/AzaharSf/AzaharSf.apk /system/app/AzaharSf/AzaharSf.apk"
dbg "sif /system/app/AzaharSf/AzaharSf.apk mode 0100644"
dbg "write $S/system/app/AzaharSf/oat/arm64/AzaharSf.odex /system/app/AzaharSf/oat/arm64/AzaharSf.odex"
dbg "sif /system/app/AzaharSf/oat/arm64/AzaharSf.odex mode 0100644"
dbg "write $S/system/app/AzaharSf/oat/arm64/AzaharSf.vdex /system/app/AzaharSf/oat/arm64/AzaharSf.vdex"
dbg "sif /system/app/AzaharSf/oat/arm64/AzaharSf.vdex mode 0100644"

# azahar assets (cheats only)
dbg "mkdir /system/etc/azahar-nano"
dbg "write $S/system/etc/azahar-nano/cheats3ds.zip /system/etc/azahar-nano/cheats3ds.zip"
dbg "sif /system/etc/azahar-nano/cheats3ds.zip mode 0100644"

echo "p4 done"
sudo dumpe2fs -h $IMG 2>/dev/null | grep -E 'Free blocks|Free inodes'
