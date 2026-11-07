#!/system/bin/sh
# Pocket AIS (RK3562) — WiFi watchdog（SDIO 版）
#
# 为什么不直接用 NGP45HT 的 rg52-wifi-watchdog-v2.sh：那份是给 **USB** AIC8800DC
# 写的，恢复阶梯里有 USB unbind/bind 和 aic8800_fdrv_usb/aic_load_fw_usb 重载。
# 本机 WiFi 挂在 SDIO 上（实测 wlan0 -> ../../../mmc2:6721:1，/proc/modules 里是
# aic8800_fdrv + aic8800_bsp，没有 *_usb，/sys/bus/usb 里也没有 a69c 设备），
# 照搬那两级只会空转，真正该做的 SDIO 重新绑定一级都没有。
#
# 健康判据与节流策略沿用 v2（与总线无关，已在 NGP45HT 上验证过）：
#   - 只有“真断”才动手：已连接但网关 ping 不通、wlan0 消失/未 UP、
#     或驱动扫描返回 busy（AIC8800 的假死特征）。
#   - 附近没有已知 AP、刚开机还在连接时不动手，避免把正常离网当故障。
#   - 每一级都必须等到 wlan0 UP + 有 IPv4，再复验 healthy 才算成功。
#
# 恢复阶梯（本机版）：
#   1. 只重启 WiFi 栈
#   2. SDIO function unbind/bind（不重载模块）
#   3. 重载**当前在用**的那颗芯片的驱动
#
# 第 3 级的关键约束（来自 /vendor/bin/wifi_pick.sh 的注释）：
#   板子 revisions A/B 分别用 RK915 / AIC8800D80，两颗芯片共用同一个 SDIO 槽
#   和同一个电源引脚，**依次加载两个驱动会让后加载的那颗断掉前一颗的电**。
#   所以这里绝不调用 wifi_pick.sh、也不主动 insmod 另一颗芯片的驱动，
#   只按 /proc/modules 的事实重载已经在用的那一个；.ko 不在就跳过这级。

LOG=/data/local/tmp/rg52-wifi-watchdog.log
MODDIR=/vendor/lib/modules
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

# wlan0 实际绑在哪个 SDIO function 的哪个驱动上。
# 实测本机：mmc2:6721:1 -> aicwf_sdio（WiFi），mmc2:6721:2 -> aicbsp_sdio。
# 不写死这两个名字 —— 换板子/换芯片后 function 号会变。
sdio_func() {
    for drv in /sys/bus/sdio/drivers/*/; do
        for fn in "$drv"mmc*:*; do
            [ -e "$fn/driver" ] || continue
            if [ -e "$fn/net/wlan0" ]; then
                basename "$fn"
                return 0
            fi
        done
    done
    return 1
}

sdio_driver() {
    fn=$(sdio_func) || return 1
    [ -n "$fn" ] || return 1
    for drv in /sys/bus/sdio/drivers/*/; do
        [ -e "$drv$fn" ] || continue
        basename "$drv"
        return 0
    done
    return 1
}

# 当前在用的 WiFi 芯片驱动（只看事实，不猜板子修订号）
chip_modules() {
    if grep -q '^aic8800_fdrv ' /proc/modules 2>/dev/null; then
        echo aic
    elif grep -q '^rk915 ' /proc/modules 2>/dev/null; then
        echo rk915
    fi
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
    echo "useron=$(wifi_user_on && echo 1 || echo 0) on=$(wifi_on && echo 1 || echo 0) conn=$(wifi_connected && echo 1 || echo 0) up=$(iface_up && echo 1 || echo 0) ip=$(has_ip && echo 1 || echo 0) bss=$(scan_bss) gw=$(gateway) gwping=$(ping_gw && echo 1 || echo 0) fn=$(sdio_func) drv=$(sdio_driver) chip=$(chip_modules)"
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
    fn=$(sdio_func)
    drv=$(sdio_driver)
    chip=$(chip_modules)
    log "sdio fn=${fn:-none} drv=${drv:-none} chip=${chip:-none}"

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

    # 2) SDIO function 重新绑定，模块留在内存里。
    #    只动 WiFi 那个 function；bsp function 不碰，它是同一颗芯片的另一半。
    if [ -n "$fn" ] && [ -n "$drv" ]; then
        log "sdio re-bind $drv/$fn"
        svc wifi disable
        sleep 2
        ip link set wlan0 down 2>/dev/null
        echo "$fn" > "/sys/bus/sdio/drivers/$drv/unbind" 2>/dev/null
        sleep 3
        echo "$fn" > "/sys/bus/sdio/drivers/$drv/bind" 2>/dev/null
        setprop ctl.restart vendor.wifi_hal_legacy
        sleep 4
        svc wifi enable
        if wait_link 90; then
            sleep 3
            if healthy; then
                log "recover OK (sdio re-bind): $(state_line)"
                return 0
            fi
        fi
    fi

    # 3) 重载当前芯片的驱动。finit_force 是 wifi_pick.sh 用的同一个加载器
    #    （强制版本匹配），不要换成 insmod —— 模块 vermagic 与运行内核不一致。
    case "$chip" in
    aic)
        [ -s "$MODDIR/aic8800_bsp.ko" ] && [ -s "$MODDIR/aic8800_fdrv.ko" ] || {
            log "aic .ko missing, skip module reload"
            chip=
        }
        ;;
    rk915)
        [ -s "$MODDIR/rk915.ko" ] || {
            log "rk915.ko missing, skip module reload"
            chip=
        }
        ;;
    esac

    if [ -n "$chip" ]; then
        log "reload $chip modules"
        svc wifi disable
        sleep 2
        ip link set wlan0 down 2>/dev/null
        if [ "$chip" = "aic" ]; then
            rmmod aic8800_fdrv 2>/dev/null
            rmmod aic8800_bsp 2>/dev/null
            sleep 2
            /vendor/bin/finit_force "$MODDIR/aic8800_bsp.ko" 2>/dev/null
            sleep 1
            /vendor/bin/finit_force "$MODDIR/aic8800_fdrv.ko" 2>/dev/null
        else
            rmmod rk915 2>/dev/null
            sleep 2
            /vendor/bin/finit_force "$MODDIR/rk915.ko" 2>/dev/null
        fi
        # AIC8800 的固件在 insmod 后还要约 9 秒才起来（见 wifi_pick.sh 注释），
        # 这里等够再交给框架，否则会撞上 status_code=30 的自拒绝，然后罚等 5 分钟。
        sleep 12
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
    fi

    # 框架可能还要几十秒才连上，最后再等一轮
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

# 本机上没有 WiFi 驱动在跑就什么都别做（比如刷了个没带模块的镜像）。
# 直接 exit 会让 init 反复重启（rc 里没有 oneshot），所以常驻空转。
rotate_log
log "=== watchdog sdio start (pid $$) interval=${CHECK_INTERVAL}s ==="

start_epoch=$(date +%s)
last_conn=$start_epoch
bad=0
fail_run=0
skip_note=0

while true; do
    sleep "$CHECK_INTERVAL"
    rotate_log
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