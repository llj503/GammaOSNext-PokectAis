#!/system/bin/sh
# NGP45HT — optional Daijishō seed for the 3DS platform/player.
#
# The NGP45HT image ships the Leanback launcher, not Daijishō. If the user
# installs Daijishō, this waits for its database, then runs seed3ds.sql,
# which inserts the Nintendo 3DS platform and the azahar-nano player only
# when they do not exist. It never replaces the user's library.
#
# The ROM tree still needs one-time SAF authorization via "+ Paths" on the
# 3DS platform; Android does not allow shell/appops to grant that.

PKG=com.magneticchen.daijishou
DB=/data/data/$PKG/databases/Daijishou.db
SQL=/system/etc/azahar-nano/seed3ds.sql
MARK=/data/.azahar-3ds-seeded
LOG=/data/system/ngp-seed.log
: > "$LOG"
exec >>"$LOG" 2>&1
echo "seed $(date)"

[ -e "$MARK" ] && exit 0

i=0
while [ "$i" -lt 720 ]; do
    [ -f "$DB" ] && break
    if [ $((i % 10)) -eq 0 ]; then
        if pm list packages 2>/dev/null | grep -q "^package:$PKG$"; then
            am start -n "$PKG/.ui.activities.MainActivity" >/dev/null 2>&1
        fi
        echo "wait $i"
    fi
    i=$((i + 1))
    sleep 5
done

[ -f "$DB" ] || { echo "no db"; exit 0; }

UID=$(stat -c %u /data/data/$PKG)
GID=$(stat -c %g /data/data/$PKG)
am force-stop "$PKG"
sleep 1

# seed3ds.sql has a trailing extra COMMIT; keep going even if sqlite3 reports it.
sqlite3 "$DB" < "$SQL" 2>&1 | tail -2
sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1

chown "$UID:$GID" "$DB" "$DB-wal" "$DB-shm" 2>/dev/null
chmod 660 "$DB"
restorecon "$DB" 2>/dev/null

ID=$(sqlite3 "$DB" "SELECT id FROM PlatformEntity WHERE unique_id='3ds';" 2>/dev/null)
if [ -n "$ID" ]; then
    WP=/data/data/$PKG/files/platform_wallpapers
    if [ -d "$WP" ] && [ ! -f "$WP/$ID.png" ]; then
        SRC=$(ls "$WP"/*.png 2>/dev/null | head -1)
        if [ -n "$SRC" ]; then
            cp -f "$SRC" "$WP/$ID.png"
            chown "$UID:$GID" "$WP/$ID.png" 2>/dev/null
        fi
    fi
    touch "$MARK"
    chmod 600 "$MARK"
    echo "seeded 3ds platform id=$ID"
else
    echo "seed failed"
fi

am start -n "$PKG/.ui.activities.MainActivity" >/dev/null 2>&1
