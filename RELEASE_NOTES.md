## NGP45HT v26 追加修正（2026-10-28）

这三项已接入 `image_build/build_v26_ngp.sh`，详见 `docs/ngp45ht-hotfixes.md`：

1. **3DS 默认大屏布局**：`azahar` 默认 `layout_option=1`（只显示上屏），首次启动说明在下屏，看起来像黑屏。镜像现在种入 `layout_option=2` 的默认 `config.ini`。游戏运行中长按 Back 2 秒退出。
2. **Daijisho 返回键助手**：Daijisho 1.8.1 游戏列表单按 Back/B 不返回；`ngp_back_helper` 只在 Library 页补一次 Back（B 补两次），单按即可返回。
3. **WiFi 看门狗 v2**：AIC8800DC USB 假死后，v1 重载驱动常留下 wlan0 DOWN；v2 按“重启 WiFi 栈 → USB 重新枚举 → 重载驱动”恢复，并要求实际拿到 IP + 网关 ping 通。脚本替换 p5 的 `/bin/rg52-wifi-watchdog.sh`。
4. **Daijisho 3DS 平台种子**：镜像默认仍是 Leanback；如果用户自己装了 Daijisho，开机服务会在它的数据库出现后补 Nintendo 3DS 平台和 azahar-nano player，不覆盖现有库；ROM 目录仍需 + Paths 授权。

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
