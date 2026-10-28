#!/system/bin/sh
# NGP45HT (RK3562) — AIC8800DC WiFi watchdog v2
#
# v1 只在扫描失败后 rmmod/insmod；驱动被 USB 挂起 latch 后，重载驱动经常
# 留下 wlan0 DOWN，等于没恢复。
# v2 的判据和恢复阶梯：
#   - 只有“真断”才动手：已连接但网关 ping 不通、wlan0 消失/未 UP、
#     或驱动扫描返回 busy（AIC8800 的假死特征）。
#   - 附近没有已知 AP、刚开机还在连接时不动手，避免把正常离网当故障。
#   - 恢复顺序：重启 WiFi 栈 -> USB unbind/bind 重新枚举 -> 重载驱动。
#   - 每一级都必须等到 wlan0 UP + 有 IPv4 + 网关可 ping，才算成功。

LOG=/data/local/tmp/rg52-wifi-watchdog.log
DEVCACHE=/data/local/tmp/rg52-wifi-usbdev
MODDIR=/vendor/lib/modules
FWPATH=/vendor/etc/firmware/aic8800
CHECK_INTERVAL=60
CONFIRM_INTERVAL=15
START_GRACE=180
RECENT_CONN=600
MAX_FAILS=3

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

rotate_log() {
    [ -f "$LOG" ] || return 0
    sz=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
    if [ -n "$sz" ] && [ "$sz" -gt 200000 ]; then
        mv -f "$LOG" "$LOG.1"
    fi
}

wifi_user_on() {
    [ "$(settings get global wifi_on 2>/dev/null)" = "1" ]
}

wifi_on() {
    cmd wifi status 2>/dev/null | grep -qi '^Wifi is enabled' && return 0
    dumpsys wifi 2>/dev/null | grep -qi 'Wi-Fi is enabled'
}

wifi_connected() {
    cmd wifi status 2>/dev/null | grep -qi '^Wifi is connected' && return 0
    dumpsys wifi 2>/dev/null | grep -q 'Supplicant state: COMPLETED'
}

iface_up() {
    ip link show wlan0 2>/dev/null | grep -q 'state UP'
}

has_ip() {
    ip addr show wlan0 2>/dev/null | grep -q 'inet '
}

gateway() {
    ip route get 223.5.5.5 2>/dev/null | sed -n 's/.* via \([0-9.]*\) .*/\1/p' | head -n1
}

ping_gw() {
    gw=$(gateway)
    if [ -n "$gw" ]; then
        ping -c 1 -W 2 "$gw" >/dev/null 2>&1 && return 0
    fi
    ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1
}

scan_bss() {
    iw dev wlan0 scan 2>/dev/null | grep -c '^BSS'
}

scan_busy() {
    out=$(iw dev wlan0 scan 2>&1)
    n=$(printf '%s\n' "$out" | grep -c '^BSS')
    [ "$n" -gt 0 ] && return 1
    printf '%s\n' "$out" | grep -qiE 'busy|No such device|not found|failed|error|Invalid'
}

usb_dev() {
    for d in /sys/bus/usb/devices/*/; do
        [ -r "$d/idVendor" ] || continue
        [ "$(cat "$d/idVendor" 2>/dev/null)" = "a69c" ] || continue
        basename "$d"
        return 0
    done
    return 1
}

wait_link() {
    i=0
    while [ "$i" -lt "$1" ]; do
        if iface_up && has_ip; then return 0; fi
        sleep 3
        i=$((i + 3))
    done
    return 1
}

state_line() {
    echo "useron=$(wifi_user_on && echo 1 || echo 0) on=$(wifi_on && echo 1 || echo 0) conn=$(wifi_connected && echo 1 || echo 0) up=$(iface_up && echo 1 || echo 0) ip=$(has_ip && echo 1 || echo 0) bss=$(scan_bss) gw=$(gateway) gwping=$(ping_gw && echo 1 || echo 0)"
}

healthy() {
    # 用户主动关 WiFi（settings wifi_on=0）时视为无需处理
    wifi_user_on || return 0
    # 用户意图是开、但服务层 disabled / 网卡不在，属于故障
    wifi_on || return 1
    wifi_connected || return 1
    iface_up || return 1
    has_ip || return 1
    ping_gw
}

recover() {
    log "recover start: $(state_line)"
    dev=$(usb_dev)
    [ -n "$dev" ] || dev=$(cat "$DEVCACHE" 2>/dev/null)
    [ -n "$dev" ] && echo "$dev" > "$DEVCACHE"
    log "aic usb dev=${dev:-none}"

    # 1) 只重启 WiFi 栈
    svc wifi disable
    sleep 2
    setprop ctl.restart vendor.wifi_hal_legacy
    sleep 2
    svc wifi enable
    if wait_link 45; then
        sleep 3
        if healthy; then
            log "recover OK (wifi stack): $(state_line)"
            return 0
        fi
    fi

    # 2) USB 重新枚举，驱动模块不重载
    if [ -n "$dev" ]; then
        log "usb re-enumerate $dev"
        svc wifi disable
        sleep 2
        ip link set wlan0 down 2>/dev/null
        echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
        sleep 3
        echo "$dev" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
        setprop ctl.restart vendor.wifi_hal_legacy
        sleep 4
        svc wifi enable
        if wait_link 90; then
            sleep 3
            if healthy; then
                log "recover OK (usb re-enum): $(state_line)"
                return 0
            fi
        fi
    fi

    # 3) 重载驱动 + 重新枚举
    log "reload aic modules"
    svc wifi disable
    sleep 2
    ip link set wlan0 down 2>/dev/null
    [ -n "$dev" ] && echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
    rmmod aic8800_fdrv_usb 2>/dev/null
    rmmod aic_load_fw_usb 2>/dev/null
    sleep 2
    insmod "$MODDIR/aic_load_fw_usb.ko" aic_fw_path="$FWPATH" 2>/dev/null
    sleep 1
    insmod "$MODDIR/aic8800_fdrv_usb.ko" 2>/dev/null
    sleep 2
    dev2=$(usb_dev)
    [ -n "${dev2:-$dev}" ] && echo "${dev2:-$dev}" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
    setprop ctl.restart vendor.wifi_hal_legacy
    sleep 4
    svc wifi enable
    if wait_link 90; then
        sleep 3
        if healthy; then
            log "recover OK (module reload): $(state_line)"
            return 0
        fi
    fi

    # module reload 后框架可能还要几十秒才连上，最后再等一轮
    sleep 15
    if healthy; then
        log "recover OK (late): $(state_line)"
        return 0
    fi

    log "recover FAILED: $(state_line)"
    return 1
}

case "$1" in
    --check)
        log "manual check"
        dev=$(usb_dev)
        [ -n "$dev" ] && echo "$dev" > "$DEVCACHE"
        state_line
        if healthy; then echo healthy; else echo unhealthy; fi
        exit 0
        ;;
    --recover)
        log "manual recover"
        recover
        exit $?
        ;;
esac

rotate_log
log "=== watchdog v2 start (pid $$) interval=${CHECK_INTERVAL}s ==="

start_epoch=$(date +%s)
last_conn=$start_epoch
bad=0
fail_run=0
skip_note=0

while true; do
    sleep "$CHECK_INTERVAL"
    rotate_log
    now=$(date +%s)
    dev=$(usb_dev)
    [ -n "$dev" ] && echo "$dev" > "$DEVCACHE"
    wifi_connected && last_conn=$now

    if ! wifi_user_on; then
        bad=0
        continue
    fi
    if healthy; then
        bad=0
        fail_run=0
        skip_note=0
        continue
    fi

    sleep "$CONFIRM_INTERVAL"
    now=$(date +%s)
    wifi_connected && last_conn=$now
    if ! wifi_user_on; then
        bad=0
        continue
    fi
    if healthy; then
        bad=0
        fail_run=0
        skip_note=0
        continue
    fi

    if [ $((now - start_epoch)) -lt "$START_GRACE" ]; then
        if [ "$skip_note" -eq 0 ]; then
            log "startup grace, skip: $(state_line)"
            skip_note=1
        fi
        bad=0
        continue
    fi

    if scan_busy; then
        reason="driver latch"
        bad=$((bad + 1))
    else
        bss=$(scan_bss)
        if ! wifi_connected; then
            # 有别的 AP、但已经很久没连过：正常离网，不折腾
            if [ "$bss" -gt 0 ] && [ $((now - last_conn)) -gt "$RECENT_CONN" ]; then
                if [ "$skip_note" -eq 0 ]; then
                    log "no known AP (bss=$bss), skip"
                    skip_note=1
                fi
                bad=0
                continue
            fi
            # 一个 AP 都扫不到、接口还在：没网可连，不折腾
            if [ "$bss" -eq 0 ] && iface_up; then
                if [ "$skip_note" -eq 0 ]; then
                    log "no AP in range (bss=0), skip"
                    skip_note=1
                fi
                bad=0
                continue
            fi
        fi
        reason="link/connection"
        bad=$((bad + 1))
    fi

    log "unhealthy x$bad ($reason): $(state_line)"

    if [ "$bad" -ge 2 ]; then
        if recover; then
            bad=0
            fail_run=0
            skip_note=0
            last_conn=$(date +%s)
        else
            bad=0
            fail_run=$((fail_run + 1))
            if [ "$fail_run" -ge "$MAX_FAILS" ]; then
                log "recovery failed $fail_run times; backoff 30min"
                sleep 1800
                fail_run=0
            else
                sleep 60
            fi
        fi
    fi
done
