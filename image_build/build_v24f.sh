#!/bin/bash
set -euo pipefail
G=/mnt/f/pocketAis/gammaos
dbg() { local img=$1; shift; debugfs -w -R "$1" "$img" >/dev/null 2>&1 || echo "WARN: $1"; }

# ---------- p4 system: 3DS staging, Daijishō first-boot seed ----------
P4=$G/p4_new5.img
cp -f $G/p4_new.img $P4
dbg $P4 "rm /system/etc/init/azahar-nano.rc"
dbg $P4 "write $G/azahar-nano-v24f.rc /system/etc/init/azahar-nano.rc"
dbg $P4 "sif /system/etc/init/azahar-nano.rc mode 0100644"
dbg $P4 "write $G/azahar-nano-setup.sh /system/bin/azahar-nano-setup.sh"
dbg $P4 "sif /system/bin/azahar-nano-setup.sh mode 0100755"
dbg $P4 "write $G/azahar-seed-daijisho.sh /system/bin/azahar-seed-daijisho.sh"
dbg $P4 "sif /system/bin/azahar-seed-daijisho.sh mode 0100755"
dbg $P4 "write $G/daijishou-seed-clean.db /system/etc/azahar-nano/daijishou-seed.db"
dbg $P4 "sif /system/etc/azahar-nano/daijishou-seed.db mode 0100644"

# ---------- p3 boot FAT: core + AdrenoTools hooks ----------
P3=$G/p3_v24f.img
cp -f $G/p3_v24d.img $P3

# ---------- p5 vendor: v24c ----------
P5=$G/p5_v24f.img
cp -f $G/p5_v24d.img $P5

# ---------- assemble ----------
IMG=$G/pocketAis-GammaOS-20261027-v24f.img
cp -f $G/GammaOSCore-NGP45HT-20261026-v24.img $IMG
dd if=$P3 of=$IMG bs=1M seek=16 conv=notrunc status=none
dd if=$P4 of=$IMG bs=1M seek=116 conv=notrunc status=none
dd if=$P5 of=$IMG bs=1M seek=3516 conv=notrunc status=none
sync

echo "== sizes =="
ls -l $IMG
echo "== p4 free =="
sudo dumpe2fs -h $P4 2>/dev/null | grep -E 'Free blocks|Free inodes'
echo "== p4 files =="
for f in /system/etc/init/azahar-nano.rc /system/bin/azahar-nano-setup.sh /system/bin/azahar-seed-daijisho.sh /system/etc/azahar-nano/daijishou-seed.db; do
  printf '%s: ' "$f"
  debugfs -R "stat $f" $P4 2>/dev/null | awk '/Type:|Size:/{printf "%s ", $0} END{print ""}'
done
echo "== p3 /azahar =="
mdir -i $P3 -/ ::/azahar
echo "== sha256 =="
sha256sum $IMG
