#!/system/bin/sh
# First-boot seed for Daijishō: install the prepared database that already
# contains the Nintendo 3DS platform and its azahar-nano player.
# On a fresh flash Daijishō may start long after boot_completed, so wait for
# its data dir and database instead of using a short fixed timeout.
PKG=com.magneticchen.daijishou
DBDIR=/data/data/$PKG/databases
DB=$DBDIR/Daijishou.db
SEED=/system/etc/azahar-nano/daijishou-seed.db
MARK=/data/.azahar-3ds-seeded
LOG=/data/system/azahar-seed.log
: > "$LOG"
exec >>"$LOG" 2>&1
echo "seed $(date)"

[ -e "$MARK" ] && exit 0

i=0
while [ "$i" -lt 720 ]; do
    [ -d /data/data/$PKG ] && [ -f "$DB" ] && break
    if [ $((i % 10)) -eq 0 ]; then
        am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
        echo "wait $i"
    fi
    i=$((i + 1))
    sleep 5
done

[ -d /data/data/$PKG ] || { echo "no app data"; exit 0; }
[ -f "$DB" ] || { echo "no app db"; exit 0; }

am force-stop $PKG
sleep 1
UID=$(stat -c %u /data/data/$PKG)
GID=$(stat -c %g /data/data/$PKG)
mkdir -p "$DBDIR"
chown "$UID:$GID" /data/data/$PKG 2>/dev/null
chown "$UID:$GID" "$DBDIR" 2>/dev/null
chmod 771 "$DBDIR" 2>/dev/null
[ -d /data/data/$PKG/files ] && chown "$UID:$GID" /data/data/$PKG/files 2>/dev/null
[ -d /data/data/$PKG/files ] && chmod 771 /data/data/$PKG/files 2>/dev/null
cp -f "$SEED" "$DB" || exit 0
rm -f "$DB-wal" "$DB-shm"
chown "$UID:$GID" "$DB"
chmod 660 "$DB"
restorecon "$DB" 2>/dev/null

WP=/data/data/$PKG/files/platform_wallpapers
if [ -d "$WP" ] && [ ! -f "$WP/24.png" ]; then
    SRC=$(ls "$WP"/*.png 2>/dev/null | head -1)
    if [ -n "$SRC" ]; then
        cp -f "$SRC" "$WP/24.png"
        chown "$UID:$GID" "$WP/24.png"
    fi
fi

touch "$MARK"
chmod 600 "$MARK"
echo "seeded uid=$UID"
am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
