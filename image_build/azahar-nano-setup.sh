#!/system/bin/sh
# Stage the 3DS core and AdrenoTools hooks from the boot partition into /data.
# The frontend loads the core from persist.gammaos.azahar_nano.core and expects
# the hook libs in the same directory (its hook-lib dir is the core's dirname).
SRC=/mnt/boot/azahar
DST=/data
LOG=/data/system/azahar-setup.log
: > "$LOG"
exec >>"$LOG" 2>&1
echo "azahar setup $(date)"

if [ ! -s "$DST/azahar-core.so" ]; then
    cp -f "$SRC/libazahar-nano-core.so" "$DST/azahar-core.so" || exit 0
    chmod 0644 "$DST/azahar-core.so"
    echo "copied core"
fi
for f in libhook_impl.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so; do
    if [ ! -s "$DST/$f" ]; then
        cp -f "$SRC/$f" "$DST/$f" || exit 0
        chmod 0644 "$DST/$f"
        echo "copied $f"
    fi
done
setprop persist.gammaos.azahar_nano.core "$DST/azahar-core.so"
echo "core property: $(getprop persist.gammaos.azahar_nano.core)"
