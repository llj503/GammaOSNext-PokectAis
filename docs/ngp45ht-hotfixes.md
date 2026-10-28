# NGP45HT v26 追加修正（2026-10-28）

以下四项是在 NGP45HT（RK3562 / 2GB / 1024x768）的 v26 镜像上实测后补的，
均已接入 `image_build/build_v26_ngp.sh`。

## 1. 3DS 默认大屏布局（修“黑屏”）

**现象**：第一次启动《新超级马里奥兄弟2》时，上屏全黑，看起来像模拟器没跑起来；
`azahar-nano` 实际在 59.9 fps 运行。

**原因**：azahar 首次启动生成的 `config.ini` 默认 `layout_option = 1`
（Single Screen Only，只显示上屏）。这款游戏的首次启动欢迎语、金币目标、
SpotPass 说明全部画在**下屏**，上屏这时本来就是黑的，等玩家按 A。
单屏布局把下屏藏了，所以整个画面看起来永久黑屏。

**修复**：

- 仓库内 `image_build/azahar-nano-config.ini` 将 `layout_option` 设为 `2`
  （Large Screen，上屏大画面 + 右侧下屏）。
- `build_v26_ngp.sh` 把它写到 `/system/etc/azahar-nano/config.ini`。
- `azahar-nano-setup.sh` 在首次启动时，如果
  `/data/system/azahar-nano/config/config.ini` 不存在，就复制这份默认配置。
  已有配置不会被覆盖。

旧镜像可手动改：

```
sed -i 's/^layout_option = 1$/layout_option = 2/' \
  /data/system/azahar-nano/config/config.ini
```

改完重启一次。若想保留单屏，可在游戏里按 A 走完首次说明后再切回 1。

**退出游戏**：3DS 游戏运行中单按/双击 Back 都不退；**长按 Back 约 2 秒**
才会结束会话回到 Daijisho。刚进入时的欢迎页单按 Back 可以退。

## 2. Daijisho 返回键助手

**现象**：Daijisho 1.8.1 的平台游戏列表底部写着 “B BACK”，但单按 B 或 Back
都没有反应；Start 在这个列表里等于“进入/播放”，也不能当返回。

**实测**：在游戏列表里连续两次 `KEY_BACK` 可以返回；Start 会把焦点项当作
“播放/进入”，在平台轮播页会打开游戏详情。

**助手**：

- `/system/bin/ngp-back-helper.sh`
- `/system/etc/init/ngp-back-helper.rc`，服务名 `ngp_back_helper`，开机
  `sys.boot_completed=1` 启动。

行为：

- 监听 `/dev/input/event4`（gammapad 虚拟手柄）。
- 仅在 `sys.gammaos.gamepad.fg_pkg == com.magneticchen.daijishou`
  且 `selected_page_id == library` 时生效；其他 App、Daijisho 的
  Category/Apps/Settings 页、3DS 会话中都不动。
- 收到 Back(KEY_BACK)：等原键抬起后补 1 次 Back（原键 + 补键 = 双击 Back）。
- 收到 B(BTN_EAST)：补 2 次 Back。
- 补发的 Back 用时间窗抑制，避免递归。
- 在平台轮播/游戏详情页，补的 Back 是无操作，不会多退。

日志：`/data/local/tmp/ngp-back-helper.log`。
不需要时删掉 rc 和脚本即可（或 `setprop ctl.stop ngp_back_helper`）。

## 3. WiFi 看门狗 v2

**问题**：AIC8800DC 是 USB WiFi；系统挂起后驱动会把自己 latch 成
“usb disconnected”，之后所有扫描返回 busy，WiFi 整个消失。
vendor 里的 v1 每 300 秒 `rmmod/insmod` 一次，但恢复后经常留下 `wlan0` DOWN，
实际只能整机重启。

**v2**（`image_build/rg52-wifi-watchdog-v2.sh`，写入 p5 的
`/bin/rg52-wifi-watchdog.sh`，替换 v1）：

- 每 60 秒检查；用 `settings get global wifi_on` 区分“用户关 WiFi”和
  “服务层假 disabled”。
- 健康标准：已连接 + `wlan0` UP + IPv4 + 网关 ping 通；不依赖扫描 BSS。
- 故障判据：已连接但网关 ping 不通 / `wlan0` 消失或未 UP / `iw scan`
  返回 busy（AIC8800 latch）。
- 恢复阶梯：
  1. 重启 WiFi 栈，等 45 秒；
  2. USB `unbind/bind` 强制重新枚举，等 90 秒；
  3. 重载 `aic_load_fw_usb` / `aic8800_fdrv_usb` 再枚举，等 90 秒 + 15 秒。
     每一级都要等到 `wlan0` UP + IPv4 + 网关 ping 才算成功。
- 连续 3 次失败退避 30 分钟；启动 180 秒内不动作；附近没有已知 AP
  或长时间离网时不折腾。
- 日志：`/data/local/tmp/rg52-wifi-watchdog.log`。

## 4. Daijisho 3DS 平台种子（可选）

NGP45HT 镜像默认还是 Leanback，不预装 Daijisho。用户自己装了 Daijisho 后，
`ngp_seed_daijisho` 服务会等它的数据库出现（最长 1 小时），然后执行
`seed3ds.sql`：

- 只在 `PlatformEntity` 里没有 `unique_id='3ds'` 时插入 Nintendo 3DS 平台；
- 同一批插入 azahar-nano 播放器和备选播放器；
- **不替换**用户的 Daijisho 数据库，不删除现有平台/游戏；
- 给新平台补一张壁纸（从已有平台壁纸复制）；
- 打标记 `/data/.azahar-3ds-seeded`，之后不再执行。

ROM 目录仍然需要用户在 3DS 平台按一次 **+ Paths** 选 `ROMs/n3ds`；这是
Android SAF 授权，shell/appops 不能替代。授权后平台会自动扫描出游戏。

日志：`/data/system/ngp-seed.log`。如果 Daijisho 是在服务超时后才安装的，
重启一次即可重跑。

## 涉及路径

| 内容 | 镜像内路径 | 分区 |
| --- | --- | --- |
| 3DS 默认配置 | `/system/etc/azahar-nano/config.ini` | p4 |
| 返回键助手 | `/system/bin/ngp-back-helper.sh` | p4 |
| 返回键服务 | `/system/etc/init/ngp-back-helper.rc` | p4 |
| WiFi 看门狗 v2 | `/vendor/bin/rg52-wifi-watchdog.sh`（p5 内 `/bin/...`） | p5 |
| 3DS 种子 SQL | `/system/etc/azahar-nano/seed3ds.sql` | p4 |
| Daijisho 种子脚本 | `/system/bin/ngp-seed-daijisho.sh` | p4 |
| Daijisho 种子服务 | `/system/etc/init/ngp-seed-daijisho.rc` | p4 |

`build_v26_ngp.sh` 里的分区偏移：p3 16 MiB、p4 116 MiB、p5 3516 MiB。
