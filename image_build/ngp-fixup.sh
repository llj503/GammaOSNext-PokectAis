#!/system/bin/sh
# Pocket AIS 开机修正：默认桌面 LANGOS、默认输入法、显示方向、模拟器首装等一次性收尾。
#
# 本文件由 NGP45HT v42 的 ngp-fixup.sh 合并而来，但 Pocket AIS 是另一块板子，
# 以下段落**故意不搬**（搬了会坏或纯属空转），详见 docs/v43-pocketais.md：
#   * HDMI 全部（hdmi_rebind / azahar backend=drm / ngp-hdmi-ratio）——
#     本机没有 HDMI 输出：DRM 只有 card0-DSI-1，ro520c.dts 里 rk628@50 挂在
#     &i2c4 且 status="disbled"（上游拼错，等于禁用），rk628-sound 也是 disabled。
#   * 摇杆灯 / 电源灯（stickled、powerled、JoystickLedPicker 汉化）——
#     /sys/class/leds 只有 mmc0::，也没有 /dev/spidev0.0。
#   * adc-keys-ngp.kl 与 ngp-navkey.sh —— 本机 adc-keys 只上报 114/115 两个
#     音量键，没有 KEY_ESC(1) 返回键、也没有 KEY_MUTE(113) M 键，无键可绑。
#     本机沿用 /system/usr/keylayout/adc-keys.kl，且音量**不对调**
#     （NGP45HT 的阈值与物理键相反才需要对调，本机不是）。
#   * TF2 双 bind 与 /storage/EEROMS 短链接 —— 本机只有一个 TF 槽（跑系统），
#     ROM 在内置存储 /storage/emulated/0/ROMs，没有第二张卡也没有 EEROMS 卷。
#   * azahar-nano-zh / LedPicker-zh 的 bind —— 汉化 payload 不在本仓。
#
# 背景（三层叠加，缺一不可）：
#   1. 镜像默认把两个输入法包都禁用了 —— com.android.inputmethod.leanback
#      和 com.liskovsoft.leankeyboard 都在 `pm list packages -d` 里，
#      包被禁用 => IME 服务起不来 => InputMethodManager 报 mCurId=null /
#      mHaveConnection=false => 任何应用调键盘都失败。
#   2. /system/bin/rg52-ime.sh（上游 RG52 的脚本）在 boot_completed 后
#      每 2 秒刷一次、连刷 30 次，把 default_input_method 强制设成
#      com.liskovsoft.leankeyboard —— 正好是启不来的那个。
#   3. 该脚本自带逃生门：读 persist.rg52.ime，设了它就用它。
#
# 这里：① 启用内置的手柄拼音 ngp-pinyin 并设成默认；
#       ② 用 persist.rg52.ime 改掉 rg52-ime.sh 的强制目标；
#       ③ 等它的 60 秒循环跑完，再收尾设置一次（双保险）。

TAG=ngp-fixup

# 大 APK 与配置放在 p4 system 的 /system/etc/ngp（v43 把 p4 扩了 256 MiB）。
# 不能照抄 NGP45HT 放 /vendor/etc/ngp：本机 p5 vendor 只有 254.7 MiB 且已用满，
# 只剩约 2 MB，塞不下 146 MB 的模拟器 APK。
NGP_DIR=/system/etc/ngp

# 内置输入法：手柄拼音 ngp-pinyin 0.1.1（见 github.com/llj503/ngp-pinyin-ime）。
# 镜像里放在 /system/app/NgpIme/NgpIme.apk，刷完即存在，不需要用户再装。
NGP_IME=com.llj.ngpime/.NgpImeService
NGP_PKG=com.llj.ngpime
AOSP_IME=com.android.inputmethod.leanback/.service.LeanbackImeService
LEANKEY_IME=com.liskovsoft.leankeyboard/.ime.LeanbackImeService

# 默认取 ngp-pinyin；persist.rg52.ime 是上游 rg52-ime.sh 的逃生门，
# 用户显式设过就尊重它 —— 但设的包已经不存在时（比如换过输入法），
# 继续沿用只会让 rg52-ime.sh 反复指向一个空组件，这时回落到 ngp-pinyin。
IME_ID=$(getprop persist.rg52.ime)
if [ -n "$IME_ID" ] && ! pm path "${IME_ID%%/*}" >/dev/null 2>&1; then
    log -t $TAG "stale persist.rg52.ime=$IME_ID, falling back"
    IME_ID=
fi

# Pocket AIS 专有的升级路径：v24f 时代的 rg52-wifi-fix.sh 在 NgpIme 还没内置时
# 会把这个属性写成 AOSP leanback。那个值是**脚本自己写的**，不是用户在设置里选的
# （设置里换输入法只改 default_input_method，不动这个属性）。刷到 v43 后如果
# 原样沿用，内置的手柄拼音永远成不了默认。所以：值是两个系统英文键盘之一、
# 且 ngp-pinyin 已经内置时，改回 ngp-pinyin。写成之后就稳定了，不会每次开机重算。
case "$IME_ID" in
    "$AOSP_IME"|"$LEANKEY_IME")
        if pm path $NGP_PKG >/dev/null 2>&1; then
            log -t $TAG "upgrade: persist.rg52.ime=$IME_ID -> $NGP_IME"
            IME_ID=
        fi
        ;;
esac

if [ -z "$IME_ID" ]; then
    if pm path $NGP_PKG >/dev/null 2>&1; then
        IME_ID=$NGP_IME
    else
        IME_ID=$AOSP_IME
    fi
fi

log -t $TAG "start"

# ⓪0 本地 OTA：/sdcard/OTA/update-* 有包就先应用（见 docs/local-ota.md）。
#     应用成功后 ngp-ota.sh 自己重启，下面各段不会执行；校验失败只写
#     STATUS.txt，不影响本次开机。没有包时这里只花一次目录判断。
if [ -x /vendor/bin/ngp-ota.sh ]; then
    /vendor/bin/ngp-ota.sh
fi

# ⓪0b 首次开机补装镜像自带的预装应用。
#
# 整卡刷机后 /data 是空的，GammaOS 原本靠 /system/bin/setup.sh 在首启时装
# RetroArch、MiXplorer、Aurora、PPSSPP、DraStic、Flycast、M64Plus。它的触发
# 条件写在 init.rc 里：
#   on property:sys.boot_completed=1 && property:persist.gammaos.setupwizard_run=1
# 而这个属性由 SetupWizard/Nano 的首启流程写入。本机 LANGOS 接管桌面，下面
# ⓪a 又把设备直接标记为已 provision，SetupWizard 不会走完 —— 结果 setup.sh
# 一次都不跑，/system/etc 里 183 MB 的 RetroArch APK 和 357 MB 资源包永远
# 躺着，用户看到的就是"系统里没有 RetroArch"（实测 v43 整卡刷机后就是如此：
# persist.gammaos.setupwizard_run=0、setupwizard_done=0、/data/setupcompleted
# 不存在）。
#
# 这里补一次：复制 setup.sh，把 APPS_LIST 指向过滤掉 Daijisho 的列表（Daijisho
# 的 post 钩子会把 home 抢回去），并强制 FRESH_SETUP=0，免得它解包默认 ROM
# 覆盖用户数据。后台跑，不阻塞下面各段开机修正；setup.sh 成功后会自己创建
# /data/setupcompleted，之后开机就不再执行。
#
# 最多补三次：坏卡上反复解 1.3 GB 会拖垮开机，留三次重试足够了。
RESTORE_DIR=/data/ngp
mkdir -p "$RESTORE_DIR" 2>/dev/null
RA_ATT=$RESTORE_DIR/setup-restore.attempts
_ra_n=0
[ -f "$RA_ATT" ] && _ra_n=$(cat "$RA_ATT" 2>/dev/null)
case "$_ra_n" in ''|*[!0-9]*) _ra_n=0 ;; esac
if [ ! -e /data/setupcompleted ] \
   && [ "$_ra_n" -lt 3 ] \
   && [ -x /system/bin/setup.sh ] \
   && [ -f /system/etc/gammaos/apps.list ] \
   && [ "$(getprop persist.gammaos.setupwizard_run 2>/dev/null)" != "1" ] \
   && [ "$(getprop persist.gammaos.setupwizard_done 2>/dev/null)" != "1" ] \
   && ! ps -A 2>/dev/null | grep -q '[s]etup\.sh'; then
    RA_LIST=$RESTORE_DIR/apps-restore.list
    RA_SCRIPT=$RESTORE_DIR/setup-restore.sh
    grep -v '^Daijisho|' /system/etc/gammaos/apps.list > "$RA_LIST" 2>/dev/null
    sed -e "s|^APPS_LIST=.*|APPS_LIST=$RA_LIST|" \
        -e 's|^FRESH_SETUP=1$|FRESH_SETUP=0|' \
        /system/bin/setup.sh > "$RA_SCRIPT" 2>/dev/null
    if [ -s "$RA_LIST" ] && [ -s "$RA_SCRIPT" ] \
       && grep -q "^APPS_LIST=$RA_LIST$" "$RA_SCRIPT" 2>/dev/null \
       && grep -q '^FRESH_SETUP=0$' "$RA_SCRIPT" 2>/dev/null \
       && sh -n "$RA_SCRIPT" 2>/dev/null; then
        chmod 0755 "$RA_SCRIPT" 2>/dev/null
        echo $((_ra_n + 1)) > "$RA_ATT" 2>/dev/null
        log -t $TAG "first boot: installing bundled apps (attempt $((_ra_n + 1)))"
        nohup sh "$RA_SCRIPT" >/dev/null 2>&1 &
    else
        log -t $TAG "first boot: restore script generation failed"
    fi
fi

# ⓪a 默认桌面：固定为 LANGOS（com.retrofront）。
#
# LANGOS 3.7.1 内置在 /system/app/LANGOS，刷完即是默认桌面，不依赖 Daijishō。
# 上游 /system/bin/rg52-home.sh 守的是 Daijishō —— 包不在时只打一条 warning
# 就退出，等于没人兜底，home 偏好一丢就停在选择框。这里每次开机都显式指定
# 一次（幂等，成本一条 cmd）。
# 注意：必须确认包存在再设，指向不存在的组件会让 home 永久解析失败。
if pm path com.retrofront >/dev/null 2>&1; then
    cmd package set-home-activity --user 0 com.retrofront/.NativeActivity >/dev/null 2>&1
    log -t $TAG "home -> com.retrofront/.NativeActivity"

    # MANAGE_EXTERNAL_STORAGE 是 LANGOS 扫 ROM 目录用的。
    # 内置到 /system/app 后它仍需要这条授权，否则读不到存储。
    appops set com.retrofront MANAGE_EXTERNAL_STORAGE allow >/dev/null 2>&1

    # LANGOS 抢了 home 之后，LineageOS 的 SetupWizard 不会再跑。不补这几个标志，
    # Android 14 的 SettingsHomepageActivity 会以 "Device is not provisioned"
    # 直接 finish —— 实测点「设置」一闪就回桌面，日志：
    #   E SettingsHomepageActivity: Device is not provisioned, exiting Settings
    # 这里只在未 provision 时补，正常走完向导的机器不受影响。
    if [ "$(settings get global device_provisioned 2>/dev/null)" != "1" ]; then
        settings put global device_provisioned 1 >/dev/null 2>&1
        settings put secure user_setup_complete 1 >/dev/null 2>&1
        settings put secure tv_user_setup_complete 1 >/dev/null 2>&1
        log -t $TAG "provisioning flags set (setup wizard bypassed by LANGOS home)"
    fi
fi

# ⓪a-2 存储竞态：LANGOS 作为桌面会比 vold 先起，那时存储卷还没挂上，
#   它读不到上次记下的 rom_root 就直接拉起 SAF 目录选择框（开机必现）。
#   等 public 卷挂载完成后，如果前台仍是 documentsui 的选择页，重启一次
#   LANGOS —— 实测重启后直接进游戏库，不再弹框。
if pm path com.retrofront >/dev/null 2>&1; then
    _i=0
    while [ "$_i" -lt 15 ]; do
        sm list-volumes all 2>/dev/null | grep -q 'public:.*mounted' && break
        sleep 2
        _i=$((_i + 1))
    done
    # 选择框可能在存储挂上后几秒才弹，轮询 5 次（10 秒）
    _j=0
    while [ "$_j" -lt 5 ]; do
        if dumpsys window 2>/dev/null | grep -q 'documentsui.*PickActivity'; then
            am force-stop com.android.documentsui >/dev/null 2>&1
            am force-stop com.retrofront >/dev/null 2>&1
            sleep 1
            am start -n com.retrofront/com.retrofront.NativeActivity >/dev/null 2>&1
            log -t $TAG "storage came late: launcher relaunched"
            break
        fi
        sleep 2
        _j=$((_j + 1))
    done
fi

# ⓪c 锁定显示方向：让 WindowManager 忽略应用自己请求的 screenOrientation。
#
# 现象：首次开机向导、系统设置、RetroArch 等界面整个转 180 度（上下颠倒），
#   而 nano 自己的界面是正的。
# 根因：这些应用在 manifest 里请求 REVERSE_LANDSCAPE(8)，而本机
#   ro.surface_flinger.primary_display_orientation 是 ORIENTATION_0，
#   DisplayRotation 按 8 算出 ROTATION_180：
#     mLastOrientation=8 / mRotation=2   （颠倒）
#   nano 不受影响，是因为它读的是 DRM 硬件的 physical=2，自己再转 2 次抵消。
#
# 修法要两条一起用（实测对照）：
#   1) `wm set-ignore-orientation-request true`
#      在这台 ROM 上设完 1 秒内就会被复位 —— dumpsys 里的
#      `mSetIgnoreOrientationRequest=true` 只是"最后一次调用值"的记录，
#      `mRotation` 始终是 2。单靠它没用。
#   2) `wm fixed-to-user-rotation enabled`  ← 真正生效的那条
#      设完立刻：mFixedToUserRotation=true / mLastOrientation=-1 / mRotation=0，
#      10 秒后仍然保持，启动 RetroArch 后也保持。
#      它是把 display 固定跟随 user_rotation（本机 0），彻底不理会 app 请求。
#
# 与 nano 不冲突：nano 的 physical 读的是 DRM 层，不受 WM rotation 影响，
#   rotation 变 0 之后 nano 仍然 physical=2 / renderSelfRot=2，界面照样正。
#
# 只在开机执行一次，不做循环。
wm fixed-to-user-rotation enabled 2>/dev/null
wm set-ignore-orientation-request true 2>/dev/null
log -t $TAG "display rotation locked: fixed=$(dumpsys window 2>/dev/null | grep -o 'mFixedToUserRotation=[a-z]*' | head -n 1)"

# 鼠标模式切换只要 gammapad 的 Toast 提示，不要 RG52 的整屏反色闪烁。
# RG52 的 rg52-mouseflash 服务监听 sys.gammaos.gamepad.mouse_active，
# 每次切换把 accessibility_display_inversion_enabled 翻 50ms。
# persist.rg52.mouse_flash=0 会让它只记录状态、不闪；真正的中文 Toast 由
# ngp-mousehint 服务补（见 image_build/ngp-mousehint.sh）。
setprop persist.rg52.mouse_flash 0

# ⓪b 鼠标模式（gammapad）屏幕尺寸同步 —— 只做一次，不做常驻轮询。
#
# 现象：`wm size 640x480` 之后鼠标指针能看见，但点击落点整体偏移，越往
#       右下偏得越多。
#
# 根因（反汇编 gammapad + 运行时验证）：
#   1. MouseMode 的屏幕尺寸只在 loadConfig() / setActive(true) 里探测一次，
#      tick() / processEvent() 都不重新探测，改分辨率它不知道。
#   2. VirtualMouse::create(w,h) 把 ABS_X / ABS_Y 的 absinfo max 写死成
#      w-1 / h-1，指针坐标系在创建那一刻就固定了。
#   3. 探测链第一个来源是属性 persist.gammaos.gamepad.screen_w/screen_h，
#      这两个属性 gammapad 只读不写；缺省就落到 fb0 ioctl，而 fb0 永远报
#      物理分辨率（wm size 只改 SurfaceFlinger 的 override DisplayInfo，
#      不改 fb）。
#
# 这里在开机时把 `wm size` 的当前值写进那两个属性。
#
# 注意：早期版本在这段后面挂了个每 2 秒轮询的看门狗，全新刷机会不断 fork
#   `wm`（Java 进程，几十 MB），SurfaceFlinger 没就绪时进程堆积到内存耗尽，
#   表现就是开机反复重启。所以现在只做一次，不做常驻循环。
#   改完分辨率后想让指针重新对齐，重启一次 gammapad 或整机即可。
ngp_wm_size() {
    _out=$(wm size 2>/dev/null)
    _res=$(printf '%s\n' "$_out" | sed -n 's/.*Override size: *\([0-9][0-9]*\)x\([0-9][0-9]*\).*/\1x\2/p' | tail -n 1)
    [ -z "$_res" ] && \
        _res=$(printf '%s\n' "$_out" | sed -n 's/.*Physical size: *\([0-9][0-9]*\)x\([0-9][0-9]*\).*/\1x\2/p' | tail -n 1)
    NGP_W=${_res%x*}
    NGP_H=${_res#*x}
}

ngp_sync_screen_once() {
    ngp_wm_size
    case "$NGP_W" in ''|*[!0-9]*) return 1 ;; esac
    case "$NGP_H" in ''|*[!0-9]*) return 1 ;; esac
    if [ "$(getprop persist.gammaos.gamepad.screen_w)" = "$NGP_W" ] && \
       [ "$(getprop persist.gammaos.gamepad.screen_h)" = "$NGP_H" ]; then
        return 0
    fi
    setprop persist.gammaos.gamepad.screen_w "$NGP_W"
    setprop persist.gammaos.gamepad.screen_h "$NGP_H"
    log -t $TAG "gammapad screen -> ${NGP_W}x${NGP_H}"

    # 服务还没起来就别动它：init 拉起时会自己读刚写好的属性。
    [ "$(getprop init.svc.gammapad)" = "running" ] || return 0

    # 已在运行：重启一次让它重新探测。等 init 状态机走完，
    # 避免新旧两个实例并存（各建一个 VirtualMouse 就成了两个光标）。
    setprop ctl.stop gammapad
    _n=0
    while [ "$_n" -lt 20 ]; do
        [ "$(getprop init.svc.gammapad)" = "stopped" ] && break
        sleep 0.25
        _n=$((_n + 1))
    done
    pidof gammapad >/dev/null 2>&1 && { killall -9 gammapad 2>/dev/null; sleep 0.5; }
    setprop ctl.start gammapad
    log -t $TAG "gammapad restart requested"
}

ngp_sync_screen_once


# ⓪ Nano 模式方向修正（必须在 gammaos-nano 起渲染之前写好，
#    所以这一段放在脚本最前面；boot_completed 时 nano 的 home 已经
#    起来了，改属性对"下一次进 nano"生效，正好是我们要的语义）。
#
# 现象：第一次进 nano 模式整个界面是上下翻转的，随便开一个游戏后重启
#       才恢复正常。
#
# 根因（反汇编 gammaos-nano 确认）：
#   gammaos-nano 计算 DRM 旋转矩阵时读的是
#     ro.surface_flinger.primary_display_orientation
#   只认 ORIENTATION_90 / ORIENTATION_180 / ORIENTATION_270 三个值，
#   换算成 90/180/270 度。本机该属性是 ORIENTATION_0 => 换算角度 0。
#   而代码里角度为 0 时不是"用单位阵"，而是直接 b.eq 跳过整个矩阵
#   初始化块（0x15d2b8 -> 0x15d33c），矩阵留在未初始化的状态，
#   首次运行的栈内容不确定 => 画面翻转；重启后栈布局稳定 => 看起来"好了"。
#   所以"重启一次就正常"不是修好了，是撞对了。
#
# 修法：把 persist.gammaos.nano.orientation 设成 rev_landscape。
#   gammaos-nano 会打印 nano: force_orientation=rev_landscape，
#   走 DRM 自家方向路径，不再依赖那个残缺的 installOrientation 分支。
#   实测 rev_landscape 是正的（landscape / drm_flip_v=1 都还是倒的）。
#
# 只在值缺失或不合法时写，用户自己改成 portrait 之类的不动。
NANO_ORIENT=$(getprop persist.gammaos.nano.orientation)
case "$NANO_ORIENT" in
    auto|landscape|rev_landscape|portrait|rev_portrait)
        log -t $TAG "nano orientation kept: $NANO_ORIENT" ;;
    *)
        setprop persist.gammaos.nano.orientation rev_landscape
        log -t $TAG "nano orientation fixed: '$NANO_ORIENT' -> rev_landscape" ;;
esac
# drm_flip_h/v 是用户级微调，默认必须是 0；这两个值非 0 会叠加翻转。
[ "$(getprop persist.gammaos.nano.drm_flip_h)" = "" ] && \
    setprop persist.gammaos.nano.drm_flip_h 0
[ "$(getprop persist.gammaos.nano.drm_flip_v)" = "" ] && \
    setprop persist.gammaos.nano.drm_flip_v 0

# ① 启用 AOSP leanback 输入法（幂等，留作英文回退）
pm enable com.android.inputmethod.leanback >/dev/null 2>&1

# ② 改掉 rg52-ime.sh 的强制目标
setprop persist.rg52.ime $IME_ID

# ②b 性能悬浮窗：默认不开，需要时点桌面「NGP 悬浮窗开关」图标。
#
#   帧率来自 SurfaceFlinger TimeStats，需要 root；而 app 进程 CapBnd 为空，
#   调 su 提权必然 EPERM（Android 设计），所以拆成"root 守护进程写文件、
#   app 读文件"两个进程：
#     - ngp-statd 由 init 起（/vendor/etc/init/ngp-statd.rc）常驻，但只在
#       com.ngp.overlay 进程存在时才真正采样；app 没开就 5 秒空转一次，
#       完全不碰 SurfaceFlinger（每次采样都要 fork 一个 dumpsys/JVM，
#       不开悬浮窗时没必要付这笔开销）。
#     - app 自己也不许开机自启：manifest 里有 BOOT_COMPLETED 接收器，
#       这里用 appops 掐掉。桌面图标（ToggleActivity）手动点仍然正常。
if [ -x /vendor/bin/ngp-statd ] && ! pidof ngp-statd >/dev/null 2>&1; then
    # init 服务没起来时补拉一次（不是循环，避免早期那种常驻轮询的坑）
    setprop ctl.start ngp_statd >/dev/null 2>&1
fi
if pm path com.ngp.overlay >/dev/null 2>&1; then
    appops set com.ngp.overlay SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1

    # 掐掉开机自启：只把 BOOT_COMPLETED / MY_PACKAGE_REPLACED 这个接收器
    # 组件禁掉，包本身不禁用，桌面图标（ToggleActivity）与手动 am start
    # 都不受影响。
    #
    # 为什么不用别的写法（都实测过）：
    #   - `cmd appops set ... BOOT_COMPLETED ignore` → 本机报
    #     Unknown operation string，这个 ROM 上没有该 op 名；
    #   - `am set-standby-bucket ... restricted` → 能拦住开机广播，但
    #     用户每打开一次 app，系统就把它重置回 active，等于没设；
    #   - 只靠 force-stop → 有效且 stopped 状态能跨重启，但用户用过一次
    #     就会清掉标记，下次开机又自启。
    pm disable com.ngp.overlay/.BootReceiver >/dev/null 2>&1

    # 首次开机兜底：/data 全新时上面那条还没执行过，BootReceiver 已经把
    # 悬浮窗拉起来了，这里停掉（顺带把 app 置为 stopped 状态）。
    am force-stop com.ngp.overlay >/dev/null 2>&1

    log -t $TAG "overlay: autostart off, open from launcher"
fi

# ③ 等 rg52-ime.sh 的 60 秒循环跑完，再定终态输入法。
#
# 为什么必须是这个顺序：rg52-ime.sh 在 boot_completed 后每 2 秒刷一次
# default_input_method、连刷 30 次，抢在它前面设没用。它读 persist.rg52.ime
# 当目标（上面已经写好），所以循环跑完后终态就是我们要的那个 —— 这里再补
# 一次是双保险，覆盖 rg52-ime.sh 因故没跑的情况。
#
# 系统自带的两个键盘（AOSP leanback、LeanKey）都只有英文，没有中文拼音，
# 所以默认必须落在 ngp-pinyin 上。
sleep 70

# enabled_input_methods 必须先写全，否则 ime set 会报
# "Unknown input method ... cannot be selected for user #0"。
# 保留 leanback / LeanKey 是为了系统里还有可切换的英文键盘。
settings put secure enabled_input_methods \
    "$NGP_IME:$AOSP_IME:$LEANKEY_IME" >/dev/null 2>&1
ime enable $NGP_IME >/dev/null 2>&1
ime enable $AOSP_IME >/dev/null 2>&1

if [ "$(settings get secure default_input_method 2>/dev/null)" != "$IME_ID" ]; then
    ime set "$IME_ID" >/dev/null 2>&1
fi

log -t $TAG "ime -> $(settings get secure default_input_method 2>/dev/null)"

# ③b 无障碍按键过滤（ngp-pinyin 0.1.1）：LocalSend 等 Flutter 应用在自己的
#     引擎里吃掉硬件按键，输入法收不到。启用同 APK 里的 NgpKeyFilterService：
#     输入法显示时先接住手柄键，隐藏时所有按键原样透传。
#     保留用户已启用的其他无障碍服务，只追加不覆盖。
A11Y=com.llj.ngpime/com.llj.ngpime.NgpKeyFilterService
if pm path $NGP_PKG >/dev/null 2>&1; then
    A11Y_LIST=$(settings get secure enabled_accessibility_services 2>/dev/null)
    case "$A11Y_LIST" in
        *"$A11Y"*) ;;
        ""|null) settings put secure enabled_accessibility_services "$A11Y" >/dev/null 2>&1 ;;
        *) settings put secure enabled_accessibility_services "$A11Y_LIST:$A11Y" >/dev/null 2>&1 ;;
    esac
    settings put secure accessibility_enabled 1 >/dev/null 2>&1
    log -t $TAG "a11y -> $(settings get secure enabled_accessibility_services 2>/dev/null)"
fi

# ④ 联网验证改用国内可达的探测点。
#    默认是 connectivitycheck.gstatic.com/generate_204，国内连不上 =>
#    系统判"受限/未连接互联网"，但实际能上网。
settings put global captive_portal_http_url "http://connect.rom.miui.com/generate_204"
settings put global captive_portal_https_url "https://connect.rom.miui.com/generate_204"
settings put global captive_portal_fallback_url "http://connect.rom.miui.com/generate_204"
settings put global captive_portal_use_https 0
log -t $TAG "captive portal -> miui"

# ⑦ 手柄自愈。
#
# gammapad 启动时会做一次 re-hid：grab 物理手柄 → 读能力位 → unregister 物理
# input device（把它从 Android 视野里藏掉）→ 注册一个同 VID/PID 的虚拟手柄冒充。
# 正常时 /dev/input/event4 消失、虚拟的 /dev/input/event5 顶上，用户无感。
#
# 但有时序竞态：偶尔它会卡在
#   gammapad: Re-hid reappeared source node: /dev/input/event4 (major=13 minor=68)
# 每秒一条无限重试，虚拟手柄也收不到事件。表现就是"系统假死、所有按键失效"。
#
# 官方留了 /system/bin/gammapad_restore 干这个（把物理手柄的 evdev 重新注册
# 回来），只是没做自动触发。这里补上。
#
# 判据（两条，任一命中就修）：
#   1. 物理和虚拟手柄的节点一个都打不开
#   2. logcat 里 Re-hid reappeared 超过 5 条（正常是 0 条，卡住时每秒 +1）
# 注意：**不能看 sysfs 判断**。物理设备被摘掉后 /sys/class/input/event4 还在、
# dev 号也还在、/proc/devices 里 13 input 也在，但内核 cdev 已经没了，
# open 会报 ENOENT。只有 getevent 能反映真实可用性。
if [ "$(getprop persist.gammaos.gamepad.enable 2>/dev/null)" = "1" ]; then
    _phys=0
    _virt=0
    for _e in /dev/input/event*; do
        _nm=$(getevent -i "$_e" 2>/dev/null | grep -m1 "name:")
        case "$_nm" in
            *retrogame_joypad*)           _phys=1 ;;
            *"Xbox Wireless Controller"*) _virt=1 ;;
        esac
    done
    _rehid=$(logcat -d -s gammapad 2>/dev/null | grep -c "Re-hid reappeared")
    [ -z "$_rehid" ] && _rehid=0

    _bad=""
    if [ "$_phys" = "0" ] && [ "$_virt" = "0" ]; then
        _bad="no node"
    elif [ "$_rehid" -gt 5 ]; then
        _bad="rehid loop $_rehid"
    fi

    if [ -z "$_bad" ]; then
        log -t $TAG "gamepad ok (phys=$_phys virt=$_virt rehid=$_rehid)"
    else
        log -t $TAG "gamepad bad ($_bad), restoring"
        stop gammapad 2>/dev/null
        /system/bin/gammapad_restore 2>/dev/null
        sleep 1
        start gammapad 2>/dev/null
        sleep 8
        # 修完再验一次：还是坏的就把 gammapad 关掉，至少保证物理手柄能用
        _ok2=0
        for _e in /dev/input/event*; do
            _nm=$(getevent -i "$_e" 2>/dev/null | grep -m1 "name:")
            case "$_nm" in
                *retrogame_joypad*|*"Xbox Wireless Controller"*) _ok2=1 ;;
            esac
        done
        _rehid2=$(logcat -d -s gammapad 2>/dev/null | grep -c "Re-hid reappeared")
        [ -z "$_rehid2" ] && _rehid2=0
        if [ "$_ok2" = "0" ] || [ "$_rehid2" -gt "$((_rehid + 5))" ]; then
            log -t $TAG "gamepad still bad (rehid=$_rehid2), leaving gammapad off"
            stop gammapad 2>/dev/null
            /system/bin/gammapad_restore 2>/dev/null
        else
            log -t $TAG "gamepad recovered (rehid=$_rehid2)"
        fi
    fi
fi

# ⑧ RetroArch 简体中文 + CJK 字体。
#
# RA 的 ozone/xmb 菜单默认用内置 ASCII 字体，没有 CJK 字形 —— 语言切到中文后
# 所有汉字都变成方框。又因为系统自带的 NotoSansCJK 是 .ttc collection，RA 用的
# stb_truetype 不支持 collection，指过去也无效，必须用单文件 ttf。
#
# ⚠ 早先版本（已删除的 ngp-fixup_new3.sh / fix_ra_font.sh）把字体指向
#   NotoSansCJK-Regular.ttc，那是无效的（stb_truetype 读不了 collection），
#   这里改成 NGP45HT 实测可用的单文件 ttf。
#
# /system/fonts/CarroisGothicSC-Regular.ttf 是镜像里现成的纯 ttf 字体
# （40356 字节，md5 a43f5aaf82ae9d3e3dbfc2dde2c0ba88），复制到 RA 的 files 目录
# 再把三个字体项指过去即可。
#
# 语言编号别写错：1.22.1 里 12 = 简体中文，11 = 繁体，10 = 韩语。
RA_DIR=/storage/emulated/0/Android/data/com.retroarch.aarch64/files
if [ -d "$RA_DIR" ]; then
    RA_FONT=$RA_DIR/zh-CN.ttf
    RA_CFG=$RA_DIR/retroarch.cfg
    if [ ! -f "$RA_FONT" ]; then
        cp -f /system/fonts/CarroisGothicSC-Regular.ttf "$RA_FONT" 2>/dev/null &&
            log -t $TAG "retroarch zh font installed"
    fi
    if [ -f "$RA_FONT" ] && [ -f "$RA_CFG" ]; then
        RA_UID=$(stat -c %u /data/data/com.retroarch.aarch64 2>/dev/null)
        [ -n "$RA_UID" ] && chown "$RA_UID:ext_data_rw" "$RA_FONT" 2>/dev/null
        chmod 660 "$RA_FONT" 2>/dev/null

        # 只在还是出厂英文（0）时改成简体中文，用户手动选过的语言尊重不动
        if grep -q '^user_language = "0"' "$RA_CFG"; then
            sed -i 's|^user_language = .*|user_language = "12"|' "$RA_CFG"
            log -t $TAG "retroarch language -> zh_CN(12)"
        fi
        # 字体项只在空值时填，用户自己换了字体就不动
        for _k in ozone_font xmb_font video_font_path; do
            if grep -q "^$_k = \"\"" "$RA_CFG"; then
                sed -i "s|^$_k = .*|$_k = \"$RA_FONT\"|" "$RA_CFG"
            fi
        done
        if [ -n "$RA_UID" ]; then
            chown "$RA_UID:ext_data_rw" "$RA_CFG" 2>/dev/null
            chmod 660 "$RA_CFG" 2>/dev/null
        fi
        log -t $TAG "retroarch zh: lang=$(grep -m1 '^user_language' "$RA_CFG" | cut -d'"' -f2)"
    fi
fi

# ⑪ gammapad 按键重映射：手柄 Back -> KEYCODE_BACK，Guide -> KEYCODE_HOME
#
# 这一段是 Pocket AIS 专有做法，和 NGP45HT v42 相反，原因：
#   * NGP45HT 有独立的 M 键（adc-keys 113 -> BACK）和机身返回键
#     （ngp-navkey.sh），把 remap 里的 316/704 清掉后仍有人兜底；
#     本机 adc-keys 只有音量，清掉之后**没有任何返回键**。
#   * 虚拟手柄 "Xbox Wireless Controller" 用的是 /vendor Generic.kl，
#     里面没有 key 704，316 又是 BUTTON_MODE 不是 HOME；物理 704/316
#     不重映射就是两个死键。
#   * 官方 Azahar（org.azahar_emu.azahar）的抽屉菜单只认 KEYCODE_BACK
#     （EmulationActivity.dispatchKeyEvent），没有 BACK 连菜单都打不开，
#     更进不去 Gamepad 设置做 Auto-Map。
#   * LANGOS 的 NativeActivity 对主页上的 BACK 显式吞掉（"返回键在主页，
#     不退出应用"），恢复 BACK 不会把桌面顶掉。
# 所以恢复本机出厂的 `316:172,704:158`（只保留其它玩家自定义条目）。
# gammapad 只在启动时读这个属性，值变了才重启。
CUR_RM=$(getprop persist.gammaos.gamepad.remap_btn)
NEW_RM=$(echo "$CUR_RM" | tr ',' '\n' | grep -vE '^(316|704):' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
if [ -n "$NEW_RM" ]; then
    NEW_RM="$NEW_RM,704:158,316:172"
else
    NEW_RM="704:158,316:172"
fi
if [ "$NEW_RM" != "$CUR_RM" ]; then
    setprop persist.gammaos.gamepad.remap_btn "$NEW_RM"
    log -t $TAG "gamepad remap: Back->BACK, Guide->HOME ($NEW_RM)"
    # 注意：重启后物理手柄节点的 evdev 名字会消失是正常现象（它 re-hid 成虚拟手柄），
    #      不等同于「手柄坏了」，判据看虚拟设备 "Xbox Wireless Controller" 是否在。
    setprop ctl.restart gammapad 2>/dev/null
    sleep 2
    log -t $TAG "gammapad restarted after remap restore"
fi

# ⑫a LANGOS ROM 根目录。
#
# NGP45HT 用 /storage/EEROMS 短链接（它的 ROM 在独立 EEROMS 卷上）；本机没有
# 那个卷，ROM 就在内置存储的 /storage/emulated/0/ROMs，直接指过去。
# 只在首次（prefs 里还没有正确值）时写，避免覆盖用户自己改过的路径。
#
# 目录必须真实存在。反汇编 NativeActivity.scanGames() 确认：rom_root 不存在
# 且 autoDetectRomRoot() 找不到 TF 卡时，它不会扫出 0 款，而是直接
# loadMockData() —— 把开发者自己的卡 /storage/FBFB-0D4A/Roms 和写死的计数
# （FC 536、SFC 280、GB 120…）当成游戏库显示，日志：
#   D VagaRetro: TF card not accessible, using mock data
# 空目录走正常扫描，结果是 0 平台 0 款，这才是没装 ROM 该有的样子。
ROM_ROOT=/storage/emulated/0/ROMs
LPREF=/data/user/0/com.retrofront/shared_prefs/retrofront.xml
_restart_langos=0
if [ ! -d "$ROM_ROOT" ]; then
    mkdir -p "$ROM_ROOT" 2>/dev/null
    chown 1023:1023 "$ROM_ROOT" 2>/dev/null
    chmod 2770 "$ROM_ROOT" 2>/dev/null
    _restart_langos=1
    log -t $TAG "langos: created $ROM_ROOT (missing root would show built-in mock data)"
fi
if pm path com.retrofront >/dev/null 2>&1; then
    if [ ! -f "$LPREF" ]; then
        am start -n com.retrofront/.NativeActivity >/dev/null 2>&1
        sleep 3
    fi
    if [ -f "$LPREF" ]; then
        _lu=$(stat -c %u "$LPREF" 2>/dev/null)
        _lg=$(stat -c %g "$LPREF" 2>/dev/null)
        if ! grep -q "<string name=\"rom_root\">$ROM_ROOT</string>" "$LPREF" 2>/dev/null; then
            sed -i "s#<string name=\"rom_root\">[^<]*</string>#<string name=\"rom_root\">$ROM_ROOT</string>#" "$LPREF" 2>/dev/null
            [ -n "$_lu" ] && chown "$_lu:$_lg" "$LPREF" 2>/dev/null
            chmod 660 "$LPREF" 2>/dev/null
            _restart_langos=1
            log -t $TAG "langos: rom_root -> $ROM_ROOT"
        fi
    fi
fi
if [ "$_restart_langos" = 1 ]; then
    am force-stop com.retrofront >/dev/null 2>&1
    am start -n com.retrofront/.NativeActivity >/dev/null 2>&1
fi

# ⑫b 模拟器改为「可卸载」（NGP45HT v39）
#
# 预装 APK 放在 /system/etc/ngp/emulators/（不参与系统扫描），由本段首次
# pm install 成 /data/app，玩家在「应用」里能正常卸载。
#
# 卸载后不能又装回来。实测本机 `pm list packages -u` **不保留**卸载记录
# （卸载后普通列表和 -u 列表都没有），所以只能自己记：首次装成功时打标记，
# 以后发现「没装但有标记」= 玩家自己卸的，不再装。
#
# 玩家想恢复内置模拟器：删掉 /data/ngp/emu-installed/<包名> 再重启。
EMU_DIR=$NGP_DIR/emulators
EMU_MARK=/data/ngp/emu-installed
mkdir -p "$EMU_MARK" 2>/dev/null
install_emu() {
    _pkg="$1"; _apk="$2"; _name="$3"
    [ -f "$_apk" ] || return 0
    _mark="$EMU_MARK/$_pkg"
    if pm list packages 2>/dev/null | grep -qx "package:$_pkg"; then
        # 判据必须是「内容是否一致」，不能是「codePath 在不在 /data/app」。
        # 老逻辑只看路径 → 覆盖升级时 /data/app 里已有上一版，直接跳过安装，
        # 新版 APK 永远装不上（NGP45HT v37 的 HDMI 5 列就这么失效过）。
        _cur=$(pm path "$_pkg" 2>/dev/null | sed -n 's/^package://p' | head -1)
        _want=$(md5sum "$_apk" 2>/dev/null | awk '{print $1}')
        _have=""
        [ -n "$_cur" ] && _have=$(md5sum "$_cur" 2>/dev/null | awk '{print $1}')
        if [ -n "$_want" ] && [ "$_want" != "$_have" ]; then
            pm install -r "$_apk" >/dev/null 2>&1 && \
                log -t $TAG "$_name: upgraded to vendored build"
        fi
        : > "$_mark" 2>/dev/null
        return 0
    fi
    if [ -f "$_mark" ]; then
        log -t $TAG "$_name: user uninstalled, keep it uninstalled"
        return 0
    fi
    if pm install "$_apk" >/dev/null 2>&1; then
        : > "$_mark" 2>/dev/null
        log -t $TAG "$_name: installed to /data/app (player can uninstall)"
    else
        log -t $TAG "$_name: install FAILED"
    fi
}
install_emu xyz.aethersx2.android "$EMU_DIR/NetherSX2.apk" nethersx2
install_emu org.azahar_emu.azahar "$EMU_DIR/Azahar-official-2126.2.apk" "azahar-official"
# 必须用 legacy armv8.0 包：RK3562 是 Cortex-A53，armv8.2 包会在
# libemucore_4k.so 读游戏序列号时 SIGILL。
install_emu com.armsx2 "$EMU_DIR/ARMSX2-2.9.2-legacy-armv8.0.apk" armsx2

# ⑫c ARMSX2 输入语义：系统返回键 = 弹出游戏菜单，Home = 回 LANGOS。
#
# ARMSX2 2.9.2 的代码默认值是：
#   input.backOpensMenu=true   短按 Back 打开游戏菜单
#   ui.holdBackToExit=true     长按 Back 700ms 直接退出（本机没有独立返回键，
#                              系统返回手势稍慢就会变成退出；改成 false 后
#                              Back 只弹菜单，不会把游戏关掉）
#   ui.blockHomeButton=false   Home 不劫持，交给系统 -> LANGOS
# 只补 prefs 里缺失的键，玩家显式改过的值不动；holdBackToExit 没有 UI 开关，
# 默认值只写在代码里，prefs 里通常不存在，所以 ARMSX2 首次启动后的下一次开机
# 就会补上。prefs 由 ARMSX2 首次启动创建；这里只改已存在的文件，不替应用造
# 文件（app_data_file 的 SELinux 类别由 installd 管，手造容易让应用读不到）。
AX2_PREFS=/data/data/com.armsx2/shared_prefs/ARMSX2.xml
if [ -f "$AX2_PREFS" ]; then
    _ax2_tmp=/data/ngp/armsx2-prefs.$$
    _ax2_add=""
    grep -q 'name="input.backOpensMenu"' "$AX2_PREFS" || \
        _ax2_add="$_ax2_add input.backOpensMenu:true"
    grep -q 'name="ui.holdBackToExit"' "$AX2_PREFS" || \
        _ax2_add="$_ax2_add ui.holdBackToExit:false"
    grep -q 'name="ui.blockHomeButton"' "$AX2_PREFS" || \
        _ax2_add="$_ax2_add ui.blockHomeButton:false"
    if [ -n "$_ax2_add" ] && cp -f "$AX2_PREFS" "$_ax2_tmp" 2>/dev/null; then
        awk -v add="$_ax2_add" '
            BEGIN { n = split(add, a, " "); added = 0 }
            /<map *\/>/ && !added {
                print "<map>"
                for (i = 1; i <= n; i++) {
                    split(a[i], kv, ":")
                    printf "    <boolean name=\"%s\" value=\"%s\" />\n", kv[1], kv[2]
                }
                print "</map>"
                added = 1
                next
            }
            /<\/map>/ && !added {
                for (i = 1; i <= n; i++) {
                    split(a[i], kv, ":")
                    printf "    <boolean name=\"%s\" value=\"%s\" />\n", kv[1], kv[2]
                }
                added = 1
            }
            { print }
        ' "$_ax2_tmp" > "$_ax2_tmp.new"
        if [ -s "$_ax2_tmp.new" ]; then
            # cat 覆盖原文件，保住 inode 和 installd 挂的 SELinux 标签
            cat "$_ax2_tmp.new" > "$AX2_PREFS"
            chmod 660 "$AX2_PREFS" 2>/dev/null
            log -t $TAG "armsx2: input seeded (Back=menu, no hold-exit, Home->LANGOS)"
        fi
        rm -f "$_ax2_tmp" "$_ax2_tmp.new"
    fi
fi

# Azahar 官方版性能配置（Mali-G52 Vulkan）：预置到用户目录，首次向导选择该目录即可。
# graphics_api=2(Vulkan) / use_vsync=0 / resolution_factor=1 / disable_right_eye_render=1
AZAHAR_HOME=/data/media/0/azahar-emu
AZAHAR_CFG=$NGP_DIR/azahar/config.ini
if [ -f "$AZAHAR_CFG" ]; then
    mkdir -p "$AZAHAR_HOME/config" 2>/dev/null
    cp -f "$AZAHAR_CFG" "$AZAHAR_HOME/config/config.ini" 2>/dev/null && \
        log -t $TAG "azahar: config preset seeded"
    chown -R media_rw:media_rw "$AZAHAR_HOME" 2>/dev/null
    chmod 770 "$AZAHAR_HOME" "$AZAHAR_HOME/config" 2>/dev/null
    chmod 660 "$AZAHAR_HOME/config/config.ini" 2>/dev/null
fi

# ⑫d Azahar 官方版输入映射：物理 B = 3DS B，摇杆/十字键/肩键全部直通。
#
# 官方版 prefs 里没有 InputMapping 时，HotkeyUtility.getButtonSet() 返回空集，
# 手柄事件一个都到不了 native —— 表现是所有键都没反应，不只是 B。
# 这里按它自己的 Auto-Map 结果预置（Nintendo 面键 + 轴十字键 + 轴摇杆），
# 值取自 InputBindingSetting 的 nintendoFaceButtonMappings /
# commonButtonMappings / stickAxisMappings / dpadAxisMappings：
#   * 本机 abxy_swap=1，东/右键上报 BUTTON_A，Auto-Map 判定 Nintendo 布局；
#     物理 B(305 -> KEYCODE_BUTTON_B=97) -> 3DS B(701)。
#   * 十字键两套都预置：虚拟手柄同时声明 HAT 轴和 BTN_DPAD 键能力，
#     轴走 AXIS_HAT_X/Y(15/16) -> DPAD(780)，键走 DPAD_UP..RIGHT(19-22)
#     -> 709..712；实际只会上报其中一种，并存没有副作用。
#     左右摇杆走 AXIS_X/Y(0/1)、Z/RZ(11/14)。
#   * BACK 不在这里映射：⑪ 已把物理 Back 还原成 KEYCODE_BACK，Azahar 用它开抽屉。
# 只在完全没有 InputMapping 时整体预置；玩家做过 Auto-Map 就一律不碰，避免新旧值打架。
# prefs 由应用首次启动创建，不替它造文件
# （app_data_file 的 SELinux 类别由 installd 管，手造会读不到）。
AZ_PREFS=/data/data/org.azahar_emu.azahar/shared_prefs/org.azahar_emu.azahar_preferences.xml
if [ -f "$AZ_PREFS" ] && ! grep -q 'name="InputMapping_' "$AZ_PREFS"; then
    _az_tmp=/data/ngp/azahar-prefs.$$
    _az_ent=/data/ngp/azahar-input.$$
    cat > "$_az_ent" <<'AZEOF'
    <int name="InputMapping_HostAxis_96" value="700" />
    <int name="InputMapping_HostAxis_97" value="701" />
    <int name="InputMapping_HostAxis_99" value="702" />
    <int name="InputMapping_HostAxis_100" value="703" />
    <int name="InputMapping_HostAxis_102" value="773" />
    <int name="InputMapping_HostAxis_103" value="774" />
    <int name="InputMapping_HostAxis_104" value="707" />
    <int name="InputMapping_HostAxis_105" value="708" />
    <int name="InputMapping_HostAxis_108" value="704" />
    <int name="InputMapping_HostAxis_109" value="705" />
    <int name="InputMapping_HostAxis_19" value="709" />
    <int name="InputMapping_HostAxis_20" value="710" />
    <int name="InputMapping_HostAxis_21" value="711" />
    <int name="InputMapping_HostAxis_22" value="712" />
    <int name="InputMapping_HostAxis_0_GuestButton" value="713" />
    <int name="InputMapping_HostAxis_0_GuestOrientation" value="0" />
    <boolean name="InputMapping_HostAxis_0_Inverted" value="false" />
    <int name="InputMapping_HostAxis_1_GuestButton" value="713" />
    <int name="InputMapping_HostAxis_1_GuestOrientation" value="1" />
    <boolean name="InputMapping_HostAxis_1_Inverted" value="false" />
    <int name="InputMapping_HostAxis_11_GuestButton" value="718" />
    <int name="InputMapping_HostAxis_11_GuestOrientation" value="0" />
    <boolean name="InputMapping_HostAxis_11_Inverted" value="false" />
    <int name="InputMapping_HostAxis_14_GuestButton" value="718" />
    <int name="InputMapping_HostAxis_14_GuestOrientation" value="1" />
    <boolean name="InputMapping_HostAxis_14_Inverted" value="false" />
    <int name="InputMapping_HostAxis_15_GuestButton" value="780" />
    <int name="InputMapping_HostAxis_15_GuestOrientation" value="0" />
    <boolean name="InputMapping_HostAxis_15_Inverted" value="false" />
    <int name="InputMapping_HostAxis_16_GuestButton" value="780" />
    <int name="InputMapping_HostAxis_16_GuestOrientation" value="1" />
    <boolean name="InputMapping_HostAxis_16_Inverted" value="false" />
    <string name="button_a">Button A</string>
    <string name="button_b">Button B</string>
    <string name="button_x">Button X</string>
    <string name="button_y">Button Y</string>
    <string name="button_l">Button L1</string>
    <string name="button_r">Button R1</string>
    <string name="button_zl">Button L2</string>
    <string name="button_zr">Button R2</string>
    <string name="button_select">Button Select</string>
    <string name="button_start">Button Start</string>
    <string name="button_up">Dpad Up</string>
    <string name="button_down">Dpad Down</string>
    <string name="button_left">Dpad Left</string>
    <string name="button_right">Dpad Right</string>
    <string name="circlepad_axis_horizontal">Axis 0+</string>
    <string name="circlepad_axis_vertical">Axis 1-</string>
    <string name="cstick_axis_horizontal">Axis 11+</string>
    <string name="cstick_axis_vertical">Axis 14-</string>
    <string name="dpad_axis_horizontal">Axis 15+</string>
    <string name="dpad_axis_vertical">Axis 16-</string>
    <string name="InputMapping_ReverseMapping_button_a">InputMapping_HostAxis_96</string>
    <string name="InputMapping_ReverseMapping_button_b">InputMapping_HostAxis_97</string>
    <string name="InputMapping_ReverseMapping_button_x">InputMapping_HostAxis_99</string>
    <string name="InputMapping_ReverseMapping_button_y">InputMapping_HostAxis_100</string>
    <string name="InputMapping_ReverseMapping_button_l">InputMapping_HostAxis_102</string>
    <string name="InputMapping_ReverseMapping_button_r">InputMapping_HostAxis_103</string>
    <string name="InputMapping_ReverseMapping_button_zl">InputMapping_HostAxis_104</string>
    <string name="InputMapping_ReverseMapping_button_zr">InputMapping_HostAxis_105</string>
    <string name="InputMapping_ReverseMapping_button_select">InputMapping_HostAxis_109</string>
    <string name="InputMapping_ReverseMapping_button_start">InputMapping_HostAxis_108</string>
    <string name="InputMapping_ReverseMapping_button_up">InputMapping_HostAxis_19</string>
    <string name="InputMapping_ReverseMapping_button_down">InputMapping_HostAxis_20</string>
    <string name="InputMapping_ReverseMapping_button_left">InputMapping_HostAxis_21</string>
    <string name="InputMapping_ReverseMapping_button_right">InputMapping_HostAxis_22</string>
    <string name="InputMapping_ReverseMapping_circlepad_axis_horizontal_0">InputMapping_HostAxis_0</string>
    <string name="InputMapping_ReverseMapping_circlepad_axis_vertical_1">InputMapping_HostAxis_1</string>
    <string name="InputMapping_ReverseMapping_cstick_axis_horizontal_0">InputMapping_HostAxis_11</string>
    <string name="InputMapping_ReverseMapping_cstick_axis_vertical_1">InputMapping_HostAxis_14</string>
    <string name="InputMapping_ReverseMapping_dpad_axis_horizontal_0">InputMapping_HostAxis_15</string>
    <string name="InputMapping_ReverseMapping_dpad_axis_vertical_1">InputMapping_HostAxis_16</string>
AZEOF
    if cp -f "$AZ_PREFS" "$_az_tmp" 2>/dev/null; then
        awk -v f="$_az_ent" '
            /<\/map>/ && !added {
                while ((getline line < f) > 0) print line
                close(f)
                added = 1
            }
            { print }
        ' "$_az_tmp" > "$_az_tmp.new"
        if [ -s "$_az_tmp.new" ]; then
            # cat 覆盖原文件，保住 inode 和 installd 挂的 SELinux 标签
            cat "$_az_tmp.new" > "$AZ_PREFS"
            chmod 660 "$AZ_PREFS" 2>/dev/null
            log -t $TAG "azahar: input mapping seeded (Nintendo face + axis dpad/sticks)"
        fi
    fi
    rm -f "$_az_tmp" "$_az_tmp.new" "$_az_ent"
fi

# 3DS 内置前端（com.gammaos.azaharsf）动不了：它是 sharedUserId=android.uid.system
# 的 system app，要写 /data/system 并发 setprop 才能把 ROM 交给 azahar-nano，
# 重签就丢 system uid，从 /system/app 挪走同样丢。
# 玩家想换 3DS 模拟器：直接装官方的即可，LANGOS 的「选择模拟器」会把两个都列出来。
# 想让内置的彻底消失：建 /data/ngp/disable-internal-3ds，本脚本开机把它 disable。
if [ -f /data/ngp/disable-internal-3ds ]; then
    if ! pm list packages -d 2>/dev/null | grep -qx "package:com.gammaos.azaharsf"; then
        pm disable-user --user 0 com.gammaos.azaharsf >/dev/null 2>&1 && \
            log -t $TAG "azahar: builtin frontend disabled by flag"
    fi
fi

log -t $TAG "done"
