#!/bin/bash
# Assemble the Pocket AIS v43 image.
#
# v43 ports the NGP45HT v42 payload to the Pocket AIS board. What differs from
# build_v26_ngp.sh, and why:
#
#   * Big APKs go to p4 (/system/etc/ngp), not p5 (/vendor/etc/ngp). Pocket AIS
#     p5 is 254.7 MiB and already 100% full; NGP45HT grew p5 to 575 MiB. Here we
#     use p4 instead: its ext4 filesystem was built at 3003 MiB inside a 3400 MiB
#     partition, so v43 reclaims that ~397 MiB of slack with resize2fs. No GPT
#     change, no p5..p9 shift, no userdata loss.
#   * LANGOS is the default home; the legacy Daijishō seed must not launch HOME.
#   * WiFi is SDIO, so the watchdog is rg52-wifi-watchdog-sdio.sh. The USB
#     AIC8800DC ladder in rg52-wifi-watchdog-v2.sh cannot work here.
#   * HDMI, stick/power LEDs, adc-keys remap, TF2 binds and the NGP45HT SPK
#     audio patch are deliberately NOT ported. See docs/v43-pocketais.md.
#
# Usage:
#   ./build_v43_pocketais.sh <base.img> [out.img]
#
#   base.img   a Pocket AIS image (v24f or later; p3 boot FAT + p4/p5 present)
#   out.img    defaults to pocketais-v43.img
#
# The base image is never modified: it is copied first, and the p4 resize
# (if needed) runs on the copy.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IB="$ROOT/image_build"

BASE=${1:?base image}
OUT=${2:-pocketais-v43.img}
# 装完之后至少还要留这么多给运行时（日志、dexopt、后续小补丁）
HEADROOM_MIB=100

for f in LANGOS.apk ngp-ime.apk emulators/NetherSX2.apk \
         emulators/Azahar-official-2126.2.apk emulators/ARMSX2-2.9.2-legacy-armv8.0.apk \
         azahar-official-config.ini azahar-nano-setup.sh azahar-seed-daijisho.sh ngp-fixup.sh \
         ngp-ota.sh ngp-mousehint.sh ngp-mousehint.rc ngp-toast.jar \
         rg52-wifi-watchdog-sdio.sh rg52-wifi-fix.sh; do
    [ -s "$IB/$f" ] || { echo "missing payload: $IB/$f" >&2; exit 1; }
done

cp --sparse=always "$BASE" "$OUT"

# 偏移从 GPT 现读，不写死：Pocket AIS 的 p3/p4 起点与 NGP45HT 相同，但
# p5/p6/p9 尺寸不同，镜像之间不能共用常量。
p_start() { sgdisk -i "$1" "$OUT" | awk -F': *' '/First sector/ {print $2}' | awk '{print $1}'; }
p_end()   { sgdisk -i "$1" "$OUT" | awk -F': *' '/Last sector/  {print $2}' | awk '{print $1}'; }
ss=$(sgdisk -p "$OUT" | sed -n 's/^Sector size (logical): *\([0-9][0-9]*\).*/\1/p' | head -1)

# ---------- 0. p4 文件系统回收分区里没用上的空隙 ----------
# v24f 的 p4 ext4 只建到 3003 MiB，而分区是 3400 MiB：当初是把 dArkOS 的
# /system 内容重建到一个 3003 MiB 的新文件系统里，再 dd 进 NGP45HT 的分区，
# 没扩到分区大小。多出来的 ~397 MiB 一直在，只是 `df` 看不见。
# resize2fs 只追加尾部块组，不动已有共享块；也不需要改 GPT。
P4_SEC=$(( $(p_end 4) - $(p_start 4) + 1 ))
P4="$OUT?offset=$(( $(p_start 4) * ss ))"
P4_OFF_MIB=$(( $(p_start 4) * ss / 1048576 ))

free_mib() {
    read -r _fb _fbs <<<"$(debugfs -R "stats" "$P4" 2>/dev/null | \
        awk '/^Free blocks:/ {b=$3} /^Block size:/ {s=$3} END {print b, s}')" || true
    echo $(( ${_fb:-0} * ${_fbs:-4096} / 1048576 ))
}
FREE_MIB=$(free_mib)
PAYLOAD_MIB=$(( ($(stat -c %s "$IB/LANGOS.apk") \
                + $(stat -c %s "$IB/ngp-ime.apk") \
                + $(stat -c %s "$IB/emulators/NetherSX2.apk") \
                + $(stat -c %s "$IB/emulators/Azahar-official-2126.2.apk") \
                + $(stat -c %s "$IB/emulators/ARMSX2-2.9.2-legacy-armv8.0.apk")) / 1048576 \
              + 8 ))
echo "p4: $(( P4_SEC * ss / 1048576 )) MiB partition, ${FREE_MIB} MiB free, payload ~${PAYLOAD_MIB} MiB"
if [ "$FREE_MIB" -lt $((PAYLOAD_MIB + HEADROOM_MIB)) ]; then
    echo "reclaiming p4 partition slack with resize2fs (${P4_SEC}s)"
    # 不能直接 resize2fs "$OUT?offset=N"：e2fsprogs 1.47.2 会把整个镜像文件
    # ftruncate 到**文件系统大小**，完全无视 offset —— 实测这样把一张 5.2 GiB
    # 的测试镜像截成了 3400 MiB，p5..p9 全部丢失。所以抽出来按 offset 0 处理，
    # 再原样写回。
    P4_TMP="$OUT.p4-resize.img"
    trap 'rm -f "$P4_TMP"' EXIT
    dd if="$OUT" of="$P4_TMP" bs=1M skip="$P4_OFF_MIB" \
        count=$(( P4_SEC * ss / 1048576 )) conv=sparse status=none
    # e2fsck 退出码 1 = 已修正，属正常；>=4 才算失败。
    if ! e2fsck -fy "$P4_TMP" >/dev/null 2>&1; then
        rc=$?
        [ "$rc" -le 1 ] || { echo "e2fsck failed on p4 (rc=$rc)" >&2; exit 1; }
    fi
    resize2fs "$P4_TMP" "${P4_SEC}s" || resize2fs -f "$P4_TMP" "${P4_SEC}s" || {
        echo "resize2fs failed on p4" >&2; exit 1; }
    dd if="$P4_TMP" of="$OUT" bs=1M seek="$P4_OFF_MIB" conv=notrunc status=none
    rm -f "$P4_TMP"
    trap - EXIT
    FREE_MIB=$(free_mib)
    echo "p4 free after resize: ${FREE_MIB} MiB"
    if [ "$FREE_MIB" -lt $((PAYLOAD_MIB + HEADROOM_MIB)) ]; then
        echo "p4 still short: ${FREE_MIB} MiB free, need $((PAYLOAD_MIB + HEADROOM_MIB))" >&2
        echo "this base has no partition slack left; grow the partition first" >&2
        exit 1
    fi
fi

P3_OFF=$(p_start 3); P4_OFF=$(p_start 4); P5_OFF=$(p_start 5)
echo "offsets (MiB): p3=$((P3_OFF*ss/1048576)) p4=$((P4_OFF*ss/1048576)) p5=$((P5_OFF*ss/1048576))"

P5="$OUT?offset=$((P5_OFF * ss))"
# rm/mkdir 在已存在时会失败，但那正是常见情况（覆盖升级）。只告警不中断，
# 真正的结果由最后的 stat/md5 校验说了算。
dbg()  { debugfs -w -R "$1" "$P4" >/dev/null 2>&1 || echo "WARN(p4): $1" >&2; }
dbg5() { debugfs -w -R "$1" "$P5" >/dev/null 2>&1 || echo "WARN(p5): $1" >&2; }

# 写一个文件并设好 mode/uid/gid。mode 用八进制字符串，debugfs 的 sif 要
# 前导 0（0100644 = 普通文件 0644）。
put() {
    _dbg=$1; _src=$2; _dst=$3; _mode=$4; _gid=$5
    "$_dbg" "rm $_dst"
    "$_dbg" "write $_src $_dst"
    "$_dbg" "sif $_dst mode $_mode"
    "$_dbg" "sif $_dst uid 0"
    "$_dbg" "sif $_dst gid $_gid"
}

# ---------- 1. p4 system: 桌面 + 输入法 + 模拟器 + 配置 ----------
dbg "mkdir /system/app/LANGOS"
put dbg "$IB/LANGOS.apk" /system/app/LANGOS/LANGOS.apk 0100644 0

dbg "mkdir /system/app/NgpIme"
put dbg "$IB/ngp-ime.apk" /system/app/NgpIme/NgpIme.apk 0100644 0

dbg "mkdir /system/etc/ngp"
dbg "mkdir /system/etc/ngp/emulators"
dbg "mkdir /system/etc/ngp/azahar"
put dbg "$IB/emulators/NetherSX2.apk"                  /system/etc/ngp/emulators/NetherSX2.apk                  0100644 0
put dbg "$IB/emulators/Azahar-official-2126.2.apk"     /system/etc/ngp/emulators/Azahar-official-2126.2.apk     0100644 0
put dbg "$IB/emulators/ARMSX2-2.9.2-legacy-armv8.0.apk" /system/etc/ngp/emulators/ARMSX2-2.9.2-legacy-armv8.0.apk 0100644 0
put dbg "$IB/azahar-official-config.ini"               /system/etc/ngp/azahar/config.ini                        0100644 0

# 3DS core 的暂存脚本：v43 改成按大小比对，镜像升级时能替换 /data 里的旧 core。
put dbg "$IB/azahar-nano-setup.sh" /system/bin/azahar-nano-setup.sh 0100755 2000
put dbg "$IB/azahar-seed-daijisho.sh" /system/bin/azahar-seed-daijisho.sh 0100755 0

# ---------- 2. p5 vendor: 启动脚本 + Toast ----------
# /vendor/bin 的脚本沿用 build_v26 的 gid 2000 (shell)。
put dbg5 "$IB/ngp-fixup.sh"                  /bin/ngp-fixup.sh                  0100755 2000
put dbg5 "$IB/ngp-ota.sh"                    /bin/ngp-ota.sh                    0100755 2000
put dbg5 "$IB/ngp-mousehint.sh"              /bin/ngp-mousehint.sh              0100755 2000
put dbg5 "$IB/rg52-wifi-watchdog-sdio.sh"    /bin/rg52-wifi-watchdog.sh         0100755 2000
put dbg5 "$IB/rg52-wifi-fix.sh"              /bin/rg52-wifi-fix.sh              0100755 2000

dbg5 "mkdir /etc/ngp"
put dbg5 "$IB/ngp-toast.jar"       /etc/ngp/ngp-toast.jar       0100644 0
put dbg5 "$IB/ngp-mousehint.rc"    /etc/init/ngp-mousehint.rc   0100644 0

# ---------- 3. 校验 ----------
echo "== p4 space =="
debugfs -R "stats" "$P4" 2>/dev/null | grep -E "Block count|Free blocks"
echo "== p4 files (size + md5 read-back) =="
tmpx=$(mktemp)
for f in /system/app/LANGOS/LANGOS.apk \
         /system/app/NgpIme/NgpIme.apk \
         /system/etc/ngp/emulators/NetherSX2.apk \
         /system/etc/ngp/emulators/Azahar-official-2126.2.apk \
         /system/etc/ngp/emulators/ARMSX2-2.9.2-legacy-armv8.0.apk \
         /system/etc/ngp/azahar/config.ini \
         /system/bin/azahar-nano-setup.sh \
         /system/bin/azahar-seed-daijisho.sh; do
    sz=$(debugfs -R "stat $f" "$P4" 2>/dev/null | sed -n 's/.*Size: \([0-9][0-9]*\).*/\1/p' | head -1)
    printf '%-58s %s bytes\n' "$f" "${sz:-MISSING}"
done
# debugfs dump 回临时文件再算 md5，和源文件比。
for pair in "LANGOS.apk:/system/app/LANGOS/LANGOS.apk" \
            "emulators/NetherSX2.apk:/system/etc/ngp/emulators/NetherSX2.apk" \
            "azahar-seed-daijisho.sh:/system/bin/azahar-seed-daijisho.sh"; do
    src=${pair%%:*}; dst=${pair#*:}
    rm -f "$tmpx"                       # debugfs dump 不会覆盖已存在的文件
    debugfs -R "dump $dst $tmpx" "$P4" >/dev/null 2>&1
    a=$(md5sum "$IB/$src" | awk '{print $1}'); b=$(md5sum "$tmpx" | awk '{print $1}')
    [ "$a" = "$b" ] && echo "md5 OK  $dst" || { echo "md5 BAD $dst"; exit 1; }
done
rm -f "$tmpx"

echo "== p5 files =="
for f in /bin/ngp-fixup.sh /bin/ngp-ota.sh /bin/ngp-mousehint.sh \
         /bin/rg52-wifi-watchdog.sh /bin/rg52-wifi-fix.sh \
         /etc/ngp/ngp-toast.jar /etc/init/ngp-mousehint.rc; do
    printf '%-40s ' "$f"
    debugfs -R "stat $f" "$P5" 2>/dev/null | sed -n 's/.*Size: \([0-9][0-9]*\).*/\1/p' | head -1
done

echo "== GPT =="
sgdisk -v "$OUT" | tail -3
echo "== sha256 =="
sha256sum "$OUT"