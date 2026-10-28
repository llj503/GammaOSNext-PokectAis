#!/system/bin/sh
# Stage the 3DS core and AdrenoTools hooks from the boot partition into /data.
#
# Why /data and not /system:
#   1. The core is ~38 MB and /system has only ~14 MB free on this image, so it
#      does not fit there at all.
#   2. Even if it fit, libazahar-nano-core.so has to live in a directory the
#      linker namespace permits. Putting it in /vendor behind a symlink is
#      rejected (realpath not in permitted paths). /data works because the
#      frontend dlopen()s it by absolute path from the property below.
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
# screen -- looks like a permanent black screen on NGP45HT.
CFG=/data/system/azahar-nano/config/config.ini
if [ ! -s "$CFG" ]; then
    mkdir -p "$(dirname "$CFG")"
    if cp -f /system/etc/azahar-nano/config.ini "$CFG" 2>/dev/null; then
        chmod 0644 "$CFG"
        chown root:root "$CFG" 2>/dev/null
        echo "seeded azahar config (layout 2)"
    fi
fi

if [ ! -s "$DST/azahar-core.so" ]; then
    cp -f "$SRC/libazahar-nano-core.so" "$DST/azahar-core.so" || exit 0
    chmod 0644 "$DST/azahar-core.so"
    chown root:root "$DST/azahar-core.so" 2>/dev/null
    echo "copied core"
fi
for f in libhook_impl.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so; do
    if [ ! -s "$DST/$f" ]; then
        cp -f "$SRC/$f" "$DST/$f" || exit 0
        chmod 0644 "$DST/$f"
        chown root:root "$DST/$f" 2>/dev/null
        echo "copied $f"
    fi
done
setprop persist.gammaos.azahar_nano.core "$DST/azahar-core.so"
echo "core property: $(getprop persist.gammaos.azahar_nano.core)"
