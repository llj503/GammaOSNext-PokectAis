#!/system/bin/sh
# Stage the 3DS core and AdrenoTools hooks from the boot partition into /data.
#
# Why /data and not /system:
#   libazahar-nano-core.so has to live in a directory the linker namespace
#   permits. Putting it in /vendor behind a symlink is rejected (realpath not
#   in permitted paths). /data works because the frontend dlopen()s it by
#   absolute path from the property below.
#
# Unlike NGP45HT (which grew p5 to 575 MiB and stages from /vendor/azahar),
# Pocket AIS keeps the core on the p3 FAT boot partition: p5 here is only
# 254.7 MiB and already full. v43 reclaims p4's partition slack instead, for
# the LANGOS and emulator APKs; the 38 MB core stays on p3 so the same staging
# path works on both boards.
#
# The frontend derives its hook-library directory from the core's dirname, so
# the 4 AdrenoTools hooks must sit next to the core, not in /system/lib64.
SRC=/mnt/boot/azahar
DST=/data
LOG=/data/system/azahar-setup.log
: > "$LOG"
exec >>"$LOG" 2>&1
echo "azahar setup $(date)"

# The boot partition is mounted by azahar-nano.rc at post-fs-data. Mount it here
# as a fallback (a retry after the partition was remounted elsewhere) without
# clobbering an existing mount.
if [ ! -d "$SRC" ]; then
    mkdir -p /mnt/boot 0755 root root
    mount vfat /dev/block/by-name/dArkOS_Fat /mnt/boot ro 2>/dev/null
fi

if [ ! -d "$SRC" ]; then
    echo "no $SRC, nothing to stage"
    exit 0
fi

# Seed the default config once so the 3DS screens default to Large Screen
# (layout_option=2). Without it the core creates layout_option=1 (single
# screen, top only) and the first-boot intro -- which lives on the bottom
# screen -- looks like a permanent black screen.
CFG=/data/system/azahar-nano/config/config.ini
if [ ! -s "$CFG" ]; then
    mkdir -p "$(dirname "$CFG")"
    if cp -f /system/etc/azahar-nano/config.ini "$CFG" 2>/dev/null; then
        chmod 0644 "$CFG"
        chown root:root "$CFG" 2>/dev/null
        echo "seeded azahar config (layout 2)"
    fi
fi

# Copy when missing OR when the size differs -- the latter makes an image
# upgrade replace a stale core left in /data by a previous version. The old
# "[ ! -s ]" test meant an existing core was never upgraded.
stage() {
    _src="$SRC/$1"; _dst="$DST/$2"
    if [ -s "$_dst" ] && [ "$(wc -c < "$_dst")" -eq "$(wc -c < "$_src")" ]; then
        return 0
    fi
    cp -f "$_src" "$_dst" || return 1
    chmod 0644 "$_dst"
    chown root:root "$_dst" 2>/dev/null
    echo "staged $2"
}

stage libazahar-nano-core.so azahar-core.so || exit 0
for f in libhook_impl.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so; do
    stage "$f" "$f" || exit 0
done

setprop persist.gammaos.azahar_nano.core "$DST/azahar-core.so"
echo "core property: $(getprop persist.gammaos.azahar_nano.core)"
