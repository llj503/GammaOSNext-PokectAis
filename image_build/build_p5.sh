#!/bin/bash
set -euo pipefail
G=/mnt/f/pocketAis/gammaos
IMG=$G/p5_new.img
cp -f $G/v24_p5.img $IMG
dbg() { debugfs -w -R "$1" "$IMG" >/dev/null 2>&1 || echo "WARN: $1"; }

# Audio HAL: SPK -> HP
dbg "rm /lib/hw/audio.primary.rk30board.so"
dbg "write $G/audio/audio.primary.rk30board.32.so.patched /lib/hw/audio.primary.rk30board.so"
dbg "sif /lib/hw/audio.primary.rk30board.so mode 0100644"
dbg "rm /lib64/hw/audio.primary.rk30board.so"
dbg "write $G/audio/audio.primary.rk30board.so.patched /lib64/hw/audio.primary.rk30board.so"
dbg "sif /lib64/hw/audio.primary.rk30board.so mode 0100644"

# AIC8800 SDIO modules + D80 firmware + loader
dbg "rm /lib/modules/aic8800_bsp.ko"
dbg "write $G/p5add/aic8800_bsp.ko /lib/modules/aic8800_bsp.ko"
dbg "sif /lib/modules/aic8800_bsp.ko mode 0100644"
dbg "rm /lib/modules/aic8800_fdrv.ko"
dbg "write $G/p5add/aic8800_fdrv.ko /lib/modules/aic8800_fdrv.ko"
dbg "sif /lib/modules/aic8800_fdrv.ko mode 0100644"
dbg "rm /bin/finit_force"
dbg "write $G/p5add/finit_force /bin/finit_force"
dbg "sif /bin/finit_force mode 0100755"
dbg "rm /bin/wifi_pick.sh"
dbg "write $G/p5add/wifi_pick.sh /bin/wifi_pick.sh"
dbg "sif /bin/wifi_pick.sh mode 0100755"
dbg "rm /bin/rg52-wifi-watchdog.sh"
dbg "write $G/p5add/rg52-wifi-watchdog.sh /bin/rg52-wifi-watchdog.sh"
dbg "sif /bin/rg52-wifi-watchdog.sh mode 0100755"
for f in $G/p5add/*8800d80* $G/p5add/wifi_test; do
  b=$(basename "$f")
  dbg "rm /etc/firmware/aic8800/$b"
  dbg "write $f /etc/firmware/aic8800/$b"
  dbg "sif /etc/firmware/aic8800/$b mode 0100644"
done

# build.prop: add A/B swap
debugfs -R "dump /build.prop $G/p5add/build_new.prop" "$IMG" >/dev/null 2>&1
grep -q 'abxy_swap' $G/p5add/build_new.prop || echo 'persist.gammaos.gamepad.abxy_swap=1' >> $G/p5add/build_new.prop
dbg "rm /build.prop"
dbg "write $G/p5add/build_new.prop /build.prop"
dbg "sif /build.prop mode 0100644"

echo "p5 done"
ls -l $IMG
