#!/system/bin/sh
# NGP45HT — Daijisho back-key helper
#
# Daijisho 1.8.1 的 platform game list 里，单按 Back/B 不会返回（底部却写着 B BACK），
# 实际需要连续两次 KEY_BACK 才返回；Start 在列表里会被当成“进入/播放”，不能用。
#
# 助手只在 Daijisho 的 Library 页做补键（轮播/详情/游戏列表都属于 Library，
# 在轮播/详情上多补的 Back 是无操作，安全）：
#   - Back(KEY_BACK)：等原键抬起后补 1 次（原键 + 补键 = 双击 Back）
#   - B(BTN_EAST)：直接补 2 次（B 本身不参与返回）
# 前台用 gammapad 的 sys.gammaos.gamepad.fg_pkg 判断（毫秒级），
# 页签用 selected_page_id 判断，都不走慢速 dumpsys。
# 3DS(AzaharSf) 前台时完全不动：Back 由宿主退出，B 是游戏 B。
#
# 自注入抑制：补发的 KEY_BACK 也会被 getevent 读到，用时间窗忽略，避免递归。

LOG=/data/local/tmp/ngp-back-helper.log
DEV=/dev/input/event4
PREFS=/data/data/com.magneticchen.daijishou/shared_prefs/com.magneticchen.daijishou_preferences.xml
SUPPRESS=2

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

rotate_log() {
    [ -f "$LOG" ] || return 0
    sz=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
    if [ -n "$sz" ] && [ "$sz" -gt 100000 ]; then
        mv -f "$LOG" "$LOG.1"
    fi
}

inject_back() {
    sendevent "$DEV" 1 158 1
    sendevent "$DEV" 0 0 0
    sleep 0.05
    sendevent "$DEV" 1 158 0
    sendevent "$DEV" 0 0 0
    sleep 0.1
}

on_daijisho_library() {
    [ "$(getprop sys.gammaos.gamepad.fg_pkg)" = "com.magneticchen.daijishou" ] || return 1
    page=$(grep -o '<string name="selected_page_id">[^<]*' "$PREFS" 2>/dev/null | sed 's/.*>//')
    [ "$page" = "library" ]
}

while [ ! -e "$DEV" ]; do
    sleep 2
done

rotate_log
log "=== back helper start (pid $$) ==="

suppress_until=0
pending_back=0

getevent -lt "$DEV" 2>/dev/null | while read -r line; do
    now=$(date +%s)

    case "$line" in
        *KEY_BACK*DOWN*)
            if [ "$now" -le "$suppress_until" ]; then
                continue
            fi
            if on_daijisho_library; then
                pending_back=1
            fi
            ;;
        *KEY_BACK*UP*)
            if [ "$pending_back" -eq 1 ]; then
                pending_back=0
                log "library BACK -> inject 1 BACK after release"
                suppress_until=$((now + SUPPRESS))
                inject_back
            fi
            ;;
        *BTN_EAST*DOWN*)
            if [ "$now" -le "$suppress_until" ]; then
                continue
            fi
            if on_daijisho_library; then
                log "library B -> inject 2 BACK"
                suppress_until=$((now + SUPPRESS))
                inject_back
                inject_back
            fi
            ;;
    esac
done
