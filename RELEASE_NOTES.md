## Pocket AIS v43（2026-11-07）

把 NGP45HT 从 v24 到 v42 的改动里能用在 Pocket AIS 上的部分移植过来。两台机器
同 SoC、同分辨率，但音频功放接线、面板时序、WiFi 总线不同，所以是逐项适配。
每一项的取舍和实测证据见 `docs/v43-pocketais.md`。

1. **桌面切到 LANGOS 3.7.1**：内置为 system app，开机自动设为 home 并授予存储权限；
   ROM 放在 `/storage/emulated/0/ROMs`，LANGOS 直接扫描，不再需要 SAF + Paths。
2. **手柄拼音 IME**：内置 [ngp-pinyin-ime](https://github.com/llj503/ngp-pinyin-ime) 并优先作为默认；
   修复升级路径——v24f 的 `rg52-wifi-fix.sh` 曾把 `persist.rg52.ime` 写成 AOSP
   leanback，新镜像第一次开机识别并改回手柄拼音。同时启用 0.1.1 新增的
   `NgpKeyFilterService` 无障碍服务（Flutter 应用里硬件键被引擎吃掉的问题）。
3. **模拟器首装**：NetherSX2、Azahar 官方版 2126.2、ARMSX2 2.9.2（legacy armv8.0，
   armv8.2 在 Cortex-A53 上 SIGILL）。装进 `/data/app`，可正常卸载；卸载记录用
   `/data/ngp/emu-installed/<包名>` 保留。
4. **手感与显示**：鼠标模式改用中文 Toast（`persist.rg52.mouse_flash=0` 关掉整屏
   反色闪烁）；手柄 re-hid 假死开机自愈；RetroArch 补简体中文和单文件 CJK ttf
   （`.ttc` 不被 stb_truetype 支持，原 `fix_ra_font.sh` / `ngp-fixup_new3.sh` 已删除）；
   去掉 316/704 两个 remap。
5. **WiFi 看门狗重写为 SDIO 版**：本机是 AIC8800D80 SDIO，NGP45HT 的 USB 版在本机
   空转。恢复阶梯改为 WiFi 栈 → SDIO function 重新枚举 → 只重载**当前在用**的芯片
   驱动（两颗芯片共用 SDIO 槽和电源脚，绝不依次加载）。
6. **3DS**：core 复制改为按大小比对，镜像升级后 `/data` 不再留旧 core；
   `layout_option=2` 的大屏默认布局保留。
7. **p4 空间**：payload 约 152 MiB 放在 p4。本机 p5 只有 254.7 MiB 且已用
   248 MiB，没法像 NGP45HT 那样扩 p5；但 p4 的 ext4 文件系统当初只建到
   3003 MiB，分区本身是 3400 MiB，脚本用 `resize2fs` 收回这约 397 MiB 的
   历史空隙。不改 GPT，不移动 p5..p9，也不占 userdata。
8. **不移植**：HDMI 相关、摇杆/电源灯、`adc-keys-ngp.kl` / `ngp-navkey.sh`（本机
   没有那些键，音量键不能对调）、EEROMS 短链 / TF2 双 bind（单卡槽）。
   **禁止**：NGP45HT 的 SPK 音频补丁、DTB、面板时序。

镜像由 `image_build/build_v43_pocketais.sh` 从 v24f 镜像拼出，2026-11-08 已构建
`pocketAis-GammaOS-20261108-v43.img`（sha256 `7ac47811…2c4f50`）并压成
`pocketAis-GammaOS-20261108-v43.img.xz`（1,896,744,360 字节，sha256
`8836c8ef…b65a4d`）。完整校验值见 `image_build/SHA256SUMS-v43.txt`。

---

## NGP45HT v26 追加修正（2026-10-28）

这三项已接入 `image_build/build_v26_ngp.sh`，详见 `docs/ngp45ht-hotfixes.md`：

1. **3DS 默认大屏布局**：`azahar` 默认 `layout_option=1`（只显示上屏），首次启动说明在下屏，看起来像黑屏。镜像现在种入 `layout_option=2` 的默认 `config.ini`。游戏运行中长按 Back 2 秒退出。
2. **Daijisho 返回键助手**：Daijisho 1.8.1 游戏列表单按 Back/B 不返回；`ngp_back_helper` 只在 Library 页补一次 Back（B 补两次），单按即可返回。
3. **WiFi 看门狗 v2**：AIC8800DC USB 假死后，v1 重载驱动常留下 wlan0 DOWN；v2 按“重启 WiFi 栈 → USB 重新枚举 → 重载驱动”恢复，并要求实际拿到 IP + 网关 ping 通。脚本替换 p5 的 `/bin/rg52-wifi-watchdog.sh`。
4. **Daijisho 3DS 平台种子**：镜像默认仍是 Leanback；如果用户自己装了 Daijisho，开机服务会在它的数据库出现后补 Nintendo 3DS 平台和 azahar-nano player，不覆盖现有库；ROM 目录仍需 + Paths 授权。
5. **手柄拼音 IME**：预装开源离线拼音输入法 [ngp-pinyin-ime](https://github.com/llj503/ngp-pinyin-ime)（10×4 手柄网格、约 12 万词条），并把两个开机 IME 脚本改为尊重 `persist.rg52.ime`、优先手柄拼音，AOSP 保留回退。

---

Nintendo 3DS 和 DS 现在都能在这台 Mali 机器上用了。v24f 修了首次开机自动写 3DS 平台的等待问题。

1. 基于官方 NGP45HT v24（GammaOS Next Core 1.4.4），适配 Pocket AIS：ro520c DTB、1024x768 屏、AIC8800D80 SDIO WiFi、RK817 音频、A/B 按键。
2. 3DS 用 azahar-nano + Mali Vulkan；core 和 4 个 AdrenoTools hook 开机从 p3 复制到 /data；Daijishō 的 Nintendo 3DS 平台首次开机自动写入。脚本会一直等桌面建好数据库（最长 1 小时），不再用固定的 40 秒窗口。
3. 首次刷机后把 3DS ROM 放回 ROMs/n3ds，在 3DS 平台按一次 + Paths；授权一次后一直有效。DS 游戏从 GammaOS Nano 壳里的 drastic-nano 启动。
4. 已知：蓝牙未启用；Windows 上 MTP 偶发驱动 Code 19；镜像不含用户数据、ROM 和存档。

镜像：pocketAis-GammaOS-20261027-v24f.img.xz，1,814,373,412 B
SHA256：60b8bb9c65abd1116e61019ed6533b7735f1de8329b954efb0869ff4f80f3d3f

原始镜像：5,451,564,032 B
SHA256：9e4c483647c6a0242ddbb4d62ce4953ed1d199c9711ecacdf4e2074a12215d47

校验文件见 SHA256SUMS-v24f.txt。
