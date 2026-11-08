#!/bin/bash
# 生成 Pocket AIS 本地 OTA 包（目录格式，整个拷进掌机的 /sdcard/OTA/）。
#
# 用法:
#   ./make_ota_package.sh <out-root> <pkg-name> [payload...]
#
#   <out-root>   输出根目录，例如 /e/pokectais/OTA
#   <pkg-name>   包目录名，必须以 update- 开头，例如 update-20261108a
#   [payload...] 相对 image_build/ 的载荷名（见下方 dest 映射）；
#                省略则打包全部载荷（约 152 MiB）
#
# 例:
#   ./make_ota_package.sh /e/pokectais/OTA update-20261108a \
#       ngp-fixup.sh ngp-ota.sh
#
# 环境变量:
#   OTA_REBOOT=0  生成的包应用后不自动重启（默认 1）
#
# 包内布局:
#   <pkg>/README.txt
#   <pkg>/manifest.txt
#   <pkg>/payload/<相对路径>...
#
# 注意：载荷映射必须与 build_v43_pocketais.sh 保持一致，改了其中一边
# 也要改另一边（两处都有同一张表，脚本会打印每条映射供核对）。
set -euo pipefail
IB=$(cd "$(dirname "$0")" && pwd)
OUT_ROOT=${1:?out root}
PKG=${2:?package name (update-...)}
shift 2

case "$PKG" in
    update-*) ;;
    *) echo "package name must start with 'update-': $PKG" >&2; exit 1 ;;
esac
case "$PKG" in
    *[!A-Za-z0-9._-]*) echo "package name has illegal characters: $PKG" >&2; exit 1 ;;
esac
REBOOT=${OTA_REBOOT:-1}

ALL="ngp-ota.sh ngp-fixup.sh ngp-mousehint.sh rg52-wifi-watchdog-sdio.sh \
     rg52-wifi-fix.sh ngp-toast.jar ngp-mousehint.rc \
     LANGOS.apk ngp-ime.apk azahar-nano-setup.sh azahar-official-config.ini \
     emulators/NetherSX2.apk emulators/Azahar-official-2126.2.apk \
     emulators/ARMSX2-2.9.2-legacy-armv8.0.apk"

# 载荷名 -> "系统内相对路径 mode uid gid"
dest_of() {
    case "$1" in
        LANGOS.apk)                     echo "system/app/LANGOS/LANGOS.apk 0644 0 0" ;;
        ngp-ime.apk)                    echo "system/app/NgpIme/NgpIme.apk 0644 0 0" ;;
        emulators/NetherSX2.apk)        echo "system/etc/ngp/emulators/NetherSX2.apk 0644 0 0" ;;
        emulators/Azahar-official-2126.2.apk) \
                                        echo "system/etc/ngp/emulators/Azahar-official-2126.2.apk 0644 0 0" ;;
        emulators/ARMSX2-2.9.2-legacy-armv8.0.apk) \
                                        echo "system/etc/ngp/emulators/ARMSX2-2.9.2-legacy-armv8.0.apk 0644 0 0" ;;
        azahar-official-config.ini)     echo "system/etc/ngp/azahar/config.ini 0644 0 0" ;;
        azahar-nano-setup.sh)           echo "system/bin/azahar-nano-setup.sh 0755 0 2000" ;;
        ngp-fixup.sh)                   echo "vendor/bin/ngp-fixup.sh 0755 0 2000" ;;
        ngp-ota.sh)                     echo "vendor/bin/ngp-ota.sh 0755 0 2000" ;;
        ngp-mousehint.sh)               echo "vendor/bin/ngp-mousehint.sh 0755 0 2000" ;;
        rg52-wifi-watchdog-sdio.sh)     echo "vendor/bin/rg52-wifi-watchdog.sh 0755 0 2000" ;;
        rg52-wifi-fix.sh)               echo "vendor/bin/rg52-wifi-fix.sh 0755 0 2000" ;;
        ngp-toast.jar)                  echo "vendor/etc/ngp/ngp-toast.jar 0644 0 0" ;;
        ngp-mousehint.rc)               echo "vendor/etc/init/ngp-mousehint.rc 0644 0 0" ;;
        *) return 1 ;;
    esac
}

FILES=${*:-$ALL}
PKG_DIR=$OUT_ROOT/$PKG
if [ -e "$PKG_DIR" ]; then
    echo "package already exists: $PKG_DIR" >&2
    echo "delete it first (rm -rf) or pick another name" >&2
    exit 1
fi
mkdir -p "$PKG_DIR/payload"

TMP_MF=$PKG_DIR/manifest.txt
{
    echo "# Pocket AIS local OTA package"
    echo "format=1"
    echo "pkg=$PKG"
    echo "reboot=$REBOOT"
} > "$TMP_MF"

total=0
for f in $FILES; do
    map=$(dest_of "$f") || { echo "no destination mapping for: $f" >&2; exit 1; }
    read -r rel mode uid gid <<<"$map"
    src=$IB/$f
    [ -s "$src" ] || { echo "missing payload: $src" >&2; exit 1; }

    mkdir -p "$PKG_DIR/payload/${rel%/*}"
    cp -f "$src" "$PKG_DIR/payload/$rel"
    chmod "$mode" "$PKG_DIR/payload/$rel" 2>/dev/null || true
    sha=$(sha256sum "$src" | awk '{print $1}')
    echo "file|$rel|$mode|$uid|$gid|$sha" >> "$TMP_MF"

    sz=$(stat -c %s "$src")
    total=$((total + sz))
    printf '%-62s %10s bytes\n' "$rel" "$sz"
done

created=$(date '+%Y-%m-%d %H:%M:%S')
cat > "$PKG_DIR/README.txt" <<EOF
Pocket AIS 本地 OTA 包
包名: $PKG
生成: $created

用法:
  1. 把这个目录整个复制到掌机的 /sdcard/OTA/ 下（即 /sdcard/OTA/$PKG/）；
  2. 重启掌机，开机时会自动应用并再次重启；
  3. 结果看本目录的 STATUS.txt，或 adb shell cat /data/ngp/ota.log。

只替换 /system 和 /vendor 里的文件，不会动 /data 里的应用数据和 /sdcard 上的游戏。
不要修改 manifest.txt；重新生成请用 image_build/make_ota_package.sh。
EOF

echo
echo "package: $PKG_DIR"
echo "files:   $(printf '%s\n' $FILES | wc -l), total $((total / 1024 / 1024)) MiB"
echo "reboot:  $REBOOT"
