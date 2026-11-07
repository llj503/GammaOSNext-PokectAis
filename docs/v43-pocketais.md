# v43：把 NGP45HT v42 的更新移植到 Pocket AIS

v43 把 `GammaOSNext-NGP45HT` 从 v24 到 v42 的改动里，**能用在 Pocket AIS 上的部分**
搬了过来。两块板子同 SoC（RK3562 + Mali-G52）、同分辨率（1024x768），但音频功放
接线、面板时序、WiFi 总线都不一样，所以这是一次**逐项适配**，不是整包复制。

判断每一项时只有两个标准：这块板子上有没有对应硬件；搬过来会不会弄坏现有功能。

## 一、变更总览

| 项目 | 处理 | 放在哪 |
| --- | --- | --- |
| LANGOS 3.7.1 作为默认桌面 | 移植 | p4 `/system/app/LANGOS` |
| 手柄拼音 IME 0.1.1 + 无障碍按键过滤 | 移植 | p4 `/system/app/NgpIme` |
| 模拟器首装（可卸载） | 移植 | p4 `/system/etc/ngp/emulators` |
| Azahar 官方版 Mali-G52 配置 | 移植 | p4 `/system/etc/ngp/azahar` |
| 鼠标模式中文 Toast | 移植 | p5 `/etc/ngp` + `/bin/ngp-mousehint.sh` |
| 关闭整屏反色闪烁 | 移植 | `persist.rg52.mouse_flash=0` |
| 手柄 re-hid 假死自愈 | 移植 | `ngp-fixup.sh` ⑦ |
| RetroArch 简体中文 + CJK 字体 | 移植（改用 ttf） | `ngp-fixup.sh` ⑧ |
| 清掉 316/704 按键 remap | 移植 | `ngp-fixup.sh` ⑪ |
| LANGOS `rom_root` | 移植 | `ngp-fixup.sh` ⑫a |
| 3DS core 按大小升级 | 修正 | `azahar-nano-setup.sh` |
| WiFi 看门狗 | **重写为 SDIO 版** | p5 `/bin/rg52-wifi-watchdog.sh` |
| 扩大 p4 可用空间 | 新增 | `build_v43_pocketais.sh` 第 0 步（只扩文件系统） |
| HDMI 相关（5 项） | 跳过 | 本机无 HDMI 输出 |
| 摇杆灯 / 电源灯 / 灯效选择器汉化 | 跳过 | 本机无对应 LED |
| `adc-keys-ngp.kl` / `ngp-navkey.sh` | 跳过 | 本机没有那些键，且**不能对调音量** |
| EEROMS 短链 / TF2 双 bind | 跳过 | 本机单 TF 槽 |
| NGP45HT 的 SPK 音频补丁 | **禁止** | 会关掉本机功放 |
| DTB / 面板时序 | **禁止** | 会弄坏本机屏幕 |
| RK817 充电器内核补丁 | 暂缓 | 需要重新编译内核 |

## 二、payload 为什么放 p4，那 397 MiB 从哪来

v42 把 LANGOS、IME 和三个模拟器 APK 放在 p5 `/vendor/etc/ngp`。那是靠 NGP45HT
把 p5 从 254 MiB 扩到 575 MiB 换来的。

Pocket AIS 的 p5 只有 254.7 MiB，而且**已用满**：

```
/dev/block/mmcblk1p5  250M  248M  2.2M 100%  /vendor
```

p4 的文件系统也只剩约 54 MB（`df` 报 27M，差额是 root 保留块）：

```
1151123192 ... /dev/block/mmcblk1p4 2.9G 2.9G 27M 100% /
```

看起来 p4 也没地方，但分区和文件系统的大小对不上：

| 项 | 大小 |
| --- | --- |
| p4 分区（GPT） | 3400 MiB |
| p4 ext4 文件系统 | 3003 MiB |
| 差值（文件系统从未使用） | **约 397 MiB** |

原因是 v24f 的 p4 来自 dArkOS 镜像：把原 `/system` 的内容重建成一个新的
3003 MiB ext4 文件系统，再 `dd` 进 NGP45HT 的 3400 MiB 分区，之后从来没有
`resize2fs` 过。这 397 MiB 一直空在分区尾部，`df` 只按文件系统大小算，所以看不见。

而这次要装进去的 payload 约 152 MiB：

| 文件 | 大小 |
| --- | --- |
| `ARMSX2-2.9.2-legacy-armv8.0.apk` | 75,010,641 |
| `Azahar-official-2126.2.apk` | 50,187,175 |
| `NetherSX2.apk` | 21,621,788 |
| `LANGOS.apk` | 3,920,516 |
| `NgpIme.apk` | 1,131,187 |
| 其余（config / jar / 脚本） | < 50,000 |

所以 `build_v43_pocketais.sh` 第 0 步先 `e2fsck -fy`，再把 p4 文件系统
`resize2fs` 到分区本来的大小 3400 MiB。实测扩完空闲 465 MiB（397 MiB 空隙 +
原来的 51 MiB），装完 152 MiB payload 还剩 326 MiB，高于脚本要求的 100 MiB 余量。

这一步**不改 GPT**：不删/重建分区，不移动 p5..p8，不动 p9。相比“从 userdata
(p9) 借 256 MiB 再把 p5..p9 整体后移”，少了 GPT / unique GUID 写坏和平移时
覆掉源数据两类风险，也不需要牺牲 userdata 容量。曾按后者写过并验证过一个
`grow_p4.sh`；发现 p4 本身有空隙后没有采用，脚本已删除。

### 一个必须绕开的坑：resize2fs 会截断镜像文件

e2fsprogs 1.47.2 对**普通文件**的 `?offset=` 支持是半成品：`resize2fs` 结束时会
把整个文件 `ftruncate` 到**文件系统大小**，完全无视 offset。实测把一张 5.2 GiB 的
测试镜像截成了 3400 MiB——p5..p9 和备份 GPT 头一起没了。显式给大小也一样会截断
（截到新 fs 大小），不是只在“不给大小”时发生。

另外，在独立文件（offset 0）上不给大小时，`resize2fs` 会扩到**文件末尾**；如果
那个文件是整个镜像，就会盖掉后面的分区。所以任何情况下都要显式给目标大小。

脚本不直接在镜像上 resize，而是：

1. `dd` 把 p4 整段抽到 `$OUT.p4-resize.img`（3400 MiB）；
2. 在这个独立文件上 `e2fsck -fy` + `resize2fs ... "${P4_SEC}s"`——此时
   offset=0，截断恰好等于文件本身，无害；
3. `dd conv=notrunc` 写回 p4 原位置。

（用 loop device 也能避开截断，但要 root；抽出来写回不需要。）

### shared_blocks 不是问题，unshare 才是

p4 的文件系统带 `shared_blocks`（Android system 镜像的块去重）。实测
e2fsprogs 1.47.2 **可以直接扩**：扩张只在尾部追加新块组，已有共享块一个都不会
被写。

反过来，`e2fsck -E unshare_blocks` 在这块盘上**会失败**：文件系统只剩约 50 MiB
空闲，复制共享块时 ENOSPC，最后留下 0 空闲块和 "Filesystem still has errors"。
所以脚本不走这条路。

## 三、LANGOS 成为默认桌面

- 内置为普通 system app（`/system/app/LANGOS/LANGOS.apk`）。实测它**没有
  `sharedUserId`**，所以不需要重新签名，也不需要 `android.uid.system`。
- `ngp-fixup.sh` 每次开机执行 `cmd package set-home-activity --user 0
  com.retrofront/.NativeActivity`，并保留 `MANAGE_EXTERNAL_STORAGE` 授权
  （LANGOS 扫 ROM 目录要用）。设置前先 `pm path` 确认包存在，避免 home 解析
  永久失败。
- 存储竞态：LANGOS 作为桌面比 vold 先起，读不到 `rom_root` 就拉起 SAF 目录
  选择框。fixup 等 public 卷挂载后检查前台是不是 `documentsui ... PickActivity`，
  是就重启一次 LANGOS。
- `rom_root` 指向 `/storage/emulated/0/ROMs`（本机 ROM 在内置存储；NGP45HT 用
  的是独立 EEROMS 卷上的 `/storage/EEROMS`）。

## 四、输入法

沿用 NGP45HT 的三层修法，并补两处顺序要求：

1. 镜像默认禁用了 AOSP leanback 和 LeanKey 两个键盘包，先 `pm enable`。
2. `/system/bin/rg52-ime.sh` 在 `boot_completed` 后每 2 秒刷一次
   `default_input_method`、连刷 30 次，把默认值强制指向启不来的 LeanKey。它读
   `persist.rg52.ime` 当逃生门，fixup 先把这个属性写成 `ngp-pinyin`。
3. 等它 60 秒循环跑完（`sleep 70`）再定终态。

**顺序不能反**：`settings put secure enabled_input_methods` 必须先写全，否则
`ime set` 会报 `Unknown input method ... cannot be selected for user #0`。

`persist.rg52.ime` 指向的包已经不存在时（用户换过输入法），回落到 ngp-pinyin，
避免 `rg52-ime.sh` 反复指向空组件。

另外启用同 APK 里的 `NgpKeyFilterService` 无障碍服务（0.1.1 新增）：Flutter
应用（如 LocalSend）在自己的引擎里吃掉硬件按键，输入法收不到。只追加不覆盖
用户已启用的其它无障碍服务。

> `/vendor/bin/rg52-wifi-fix.sh` 里原来也有一段设 IME。两个脚本都写
> `default_input_method` 只会互相抢，v43 把那段从 wifi-fix 里删掉了。

## 五、WiFi 看门狗：为什么必须重写

NGP45HT 的 `rg52-wifi-watchdog-v2.sh` 是给 **USB** AIC8800DC 写的，恢复阶梯里
有 USB unbind/bind 和 `aic8800_fdrv_usb` / `aic_load_fw_usb` 重载。

Pocket AIS 实测：

```
wlan0 -> ../../../mmc2:6721:1
/proc/modules: aic8800_fdrv, aic8800_bsp        （没有 *_usb）
/sys/bus/usb/devices/*/idVendor 里没有 a69c
/sys/bus/sdio/drivers/: aicbsp_sdio, aicwf_sdio, btmrvl_sdio
```

照搬 v2 那两级只会空转。`rg52-wifi-watchdog-sdio.sh` 保留 v2 的健康判据和节流
策略（与总线无关，已在 NGP45HT 验证过），恢复阶梯换成：

1. 重启 WiFi 栈。
2. **SDIO function** unbind/bind（只动 WiFi 那一个 function，不重载模块）。
3. 重载**当前在用**的那颗芯片的驱动。

第 3 级的关键约束来自 `/vendor/bin/wifi_pick.sh` 的注释：板子修订 A 用 RK915、
修订 B 用 AIC8800D80，两颗芯片**共用同一个 SDIO 槽和同一个电源引脚**，依次加载
两个驱动会让后加载的那颗断掉前一颗的电。所以看门狗只按 `/proc/modules` 的事实
重载已经在用的那一个，绝不调用 `wifi_pick.sh`；`.ko` 不在就跳过这级。

驱动用 `/vendor/bin/finit_force` 加载（和 `wifi_pick.sh` 同一个加载器），
不用 `insmod`。AIC8800 的固件在 insmod 后还要约 9 秒才起来，所以重载后多等
12 秒再交给框架，否则会撞上 `status_code=30` 自拒绝、然后被罚等 5 分钟。

`rg52-wifi-fix.sh` 里的 USB 电源管理段一并删掉：本机没有 USB WiFi 设备，原来那段
只会白等 30 秒再打一条 WARN。也**没有**预防性地把 SDIO 的 `power/control` 改成
`on` —— USB 挂起 latch 是 NGP45HT 特有的故障，本机没有观测到对应的 SDIO 问题，
改了只会改变功耗行为；真断了由看门狗处理。

## 六、3DS core 升级修正

`azahar-nano-setup.sh` 原来只在 `/data/azahar-core.so` 不存在时才复制。结果镜像
升级后，`/data` 里上一版的 core 永远不会被替换。

v43 改成按大小比对（与 NGP45HT v42 一致）：目标文件存在但字节数不同就重写。

## 七、RetroArch 中文字体

原来的 `ngp-fixup_new3.sh` / `fix_ra_font.sh` 把 RA 字体指向
`NotoSansCJK-Regular.ttc`。**那是无效的**：RA 用的 stb_truetype 不支持 `.ttc`
collection，指过去汉字照样是方框。两个脚本已删除。

v43 改用镜像里现成的单文件 ttf：

```
/system/fonts/CarroisGothicSC-Regular.ttf   40356 B  md5 a43f5aaf82ae9d3e3dbfc2dde2c0ba88
```

复制到 RA 的 `files/zh-CN.ttf`，再把 `ozone_font` / `xmb_font` /
`video_font_path` 指向它。语言编号 12 = 简体中文（1.22.1）。

只在 `user_language = "0"`（出厂英文）时改语言、只在字体项为空时填字体 ——
用户手动选过的不覆盖。

## 八、刻意不移植的项

### HDMI（5 项全部跳过）

本机没有 HDMI 输出：

- DRM 里只有 `card0-DSI-1`，没有 HDMI connector。
- `ro520c.dts` 里 `rk628@50` 挂在 `&i2c4` 且 `status = "disbled"`（上游拼错的
  `disabled`，效果一样是禁用），`rk628-sound` 也是 disabled。

所以 `hdmi_rebind`、azahar `backend=drm`、`ngp-hdmi-ratio.sh`、HDMI 5 列布局、
`hdmi-1080` 都没有意义。附带一句：`wm size 1920x1080` 在这台机器上会让
system_server 崩，这也印证了 HDMI 路径不能碰。

### 摇杆灯 / 电源灯 / 灯效选择器汉化

`/sys/class/leds` 只有 `mmc0::`（TF 卡活动灯），也没有 `/dev/spidev0.0`。
`stickled`、`powerled`、`JoystickLedPicker` 汉化都没有落点。

### `adc-keys-ngp.kl` 与 `ngp-navkey.sh`

本机 adc-keys 只上报 `KEY_VOLUMEUP(115)` / `KEY_VOLUMEDOWN(114)` 两个键，没有
NGP45HT 那颗 `KEY_ESC(1)` 返回键、也没有 `KEY_MUTE(113)` M 键，无键可绑。

更要紧的是 **音量不能对调**：NGP45HT 的 DTB 阈值与物理键位置相反，才需要在
keylayout 里把 114/115 对调；本机不是，照搬会把音量键弄反。

### EEROMS 短链 / TF2 双 bind

本机只有一个 TF 槽（就是跑系统的那张），没有第二个卡槽，也没有 EEROMS 卷。
ROM 在内置存储。`ngp-eeroms-link.sh` 和 TF2 的 bind 都没有目标。

### NGP45HT 的音频补丁 / DTB / 面板时序 —— 禁止

`image_build/patch_audio_hal.py` 保留**不动**。它把 vendor HAL 里的
`SPK` 改成 `HP`，因为 Pocket AIS 的功放是 `hp2extamplifier` + `hp-ctl-gpios`；
NGP45HT 是 `spk-ctl-gpios = <&gpio0 RK_PA7>`。应用 NGP45HT 的音频改动会直接
关掉本机功放。

DTB（`rk3562-ro520c.dtb`）和面板时序同理：那是本机屏幕/WiFi 能工作的前提。

### 其它

- **RK817 充电器内核补丁**：需要重新编译内核，不属于镜像拼装范围，暂缓。
- **Native emulator 的 `ps2prefs.xml` 种子**：payload 不在本仓，没有可搬的文件。
- **`azahar-nano-zh` / `LedPicker-zh` 的 bind**：汉化 payload 不在本仓。

## 九、构建

```sh
# 在 WSL / Linux 里（需要 sgdisk、e2fsprogs、mtools）
cd image_build
./build_v43_pocketais.sh /path/to/pocketAis-v24f.img pocketais-v43.img
```

`build_v43_pocketais.sh` 先复制 base（**不改动 base**），从 GPT 现读偏移，检查
p4 空闲量；不够 152 MiB + 100 MiB 余量就 `e2fsck -fy` + `resize2fs` 到 p4 现有
分区大小（只扩文件系统）。然后写入 payload 并校验：大 APK 用 `debugfs dump`
读回算 md5 与源文件比对。

如果 base 是已经回收过空隙的镜像而空间仍然不够，脚本会报错退出，不会去改
分区表——需要扩分区时得先单独处理，不能由这个脚本顺手做。

## 十、验证记录

`build_v43_pocketais.sh` 在结构相同的 NGP45HT v38 镜像副本上做过完整端到端运行
（Pocket AIS 的 v24f base 不在本仓；两者 p4 都是 3003 MiB 文件系统 / 3400 MiB
分区）：

- 起始：`p4: 3400 MiB partition, 51 MiB free, payload ~152 MiB`，触发回收。
- 扩完：`Block count 870400`（3400 MiB），空闲 **465 MiB**；装完 payload 后
  空闲 **326 MiB**，`e2fsck -fn` 干净。
- payload 全部落位；`LANGOS.apk` 和 `NetherSX2.apk` 用 `debugfs dump` 读回算
  md5，与源文件一致。
- p5 脚本、`ngp-toast.jar`、`ngp-mousehint.rc` 都写入并可 `stat` 到。
- **GPT 未改动**：`sgdisk -v` 报 `No problems found`，空闲扇区数与改动前相同，
  p5..p9 起点不变。
- `resize2fs` 扩 `shared_blocks` 文件系统成功；`unshare_blocks` 失败（见第二节）。
- 直接对 `$IMG?offset=N` 跑 `resize2fs` 会截断镜像文件（见第二节的坑），
  脚本已改为抽取 → resize → 写回。

首次在 Pocket AIS 上跑时，建议先确认 p4 的“分区大小 / 文件系统大小”差值仍在
（`sgdisk -i 4` 与 `debugfs -R stats`），脚本会自己判断并报错。

## 十一、已知限制

- 内置 3DS 前端 `com.gammaos.azaharsf` 是 `sharedUserId=android.uid.system`
  的 system app，不能重签也不能挪出 `/system/app`。想让它消失：建
  `/data/ngp/disable-internal-3ds` 再重启。
- 模拟器装到 `/data/app` 后可正常卸载；卸载记录本机 `pm list packages -u`
  不保留，所以用 `/data/ngp/emu-installed/<包名>` 标记。想恢复：删标记再重启。
- `ARMSX2` **必须**用 legacy armv8.0 包：RK3562 是 Cortex-A53，armv8.2 包会在
  `libemucore_4k.so` 读游戏序列号时 SIGILL。
- v24f 基线里继承的 `ngp-seed-daijisho` / `ngp-back-helper` 服务在 LANGOS 作为
  桌面后是空转的（等不到 Daijishō 数据库 / 只认 Daijishō 的 Library 页），
  无害，保留未删。