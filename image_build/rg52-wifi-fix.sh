#!/system/bin/sh
# Pocket AIS (RK3562) — 开机一次性加固：WiFi 设置
# 由 /vendor/etc/init/rg52-wifi-fix.rc 在 sys.boot_completed=1 时执行（oneshot，root）
#
# 与 NGP45HT 版的两处差异：
#   * 输入法段整段删掉 —— 现在由 ngp-fixup.sh 单独负责（它要处理
#     enabled_input_methods 的写入顺序、等 rg52-ime.sh 的 60 秒循环、
#     以及 ngp-pinyin 的无障碍按键过滤）。两个脚本都写 default_input_method
#     只会互相抢，终态取决于谁后跑。
#   * AIC8800DC 的 USB 电源管理段删掉 —— 本机 WiFi 在 SDIO 上
#     （wlan0 -> mmc2:6721:1，驱动 aic8800_fdrv/aic8800_bsp），
#     /sys/bus/usb 里没有 a69c 设备，那个循环只会白等 30 秒再打一条 WARN。
#     USB 挂起 latch 是 NGP45HT 特有的故障，本机没有观测到对应的 SDIO 问题，
#     所以不预防性地改 power/control（会改变功耗行为）；真断了由
#     rg52-wifi-watchdog-sdio.sh 按阶梯恢复。

LOG=/data/local/tmp/rg52-wifi-fix.log

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

log "=== start (pid $$) ==="

# ---- 1. WiFi 设置：永不休眠、允许后台扫描、国家码 CN ----
settings put global wifi_sleep_policy 2
settings put global wifi_scan_always_enabled 1
settings put global wifi_country_code CN
log "settings: sleep=$(settings get global wifi_sleep_policy)" \
    "scan_always=$(settings get global wifi_scan_always_enabled)" \
    "cc=$(settings get global wifi_country_code)"

# ---- 2. 记录 WiFi 硬件身份，便于事后看日志判断是哪颗芯片 ----
# 板子修订 A 用 RK915、修订 B 用 AIC8800D80，共用一个 SDIO 槽。
for fn in /sys/bus/sdio/devices/*/; do
    [ -e "$fn/driver" ] || continue
    log "sdio: $(basename "$fn") drv=$(basename "$(readlink "$fn/driver")")" \
        "pm=$(cat "$fn/power/control" 2>/dev/null)"
done
log "modules: $(grep -oE '^(aic8800_fdrv|aic8800_bsp|rk915) ' /proc/modules 2>/dev/null | tr -d ' ' | tr '\n' ' ')"

log "=== done ==="
exit 0
