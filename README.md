# GammaOSNext-PokectAis

GammaOS Next（Android 14 / LineageOS 21）在 Pocket AIS（XIFAN NGP45HT，RK3562）上的移植。

## 已实现

1. 屏幕：1024x768 DSI，正立；使用 v24 官方的 WM 旋转修复。
2. WiFi：AIC8800D80 SDIO，RG52mini 驱动/固件。
3. 音频：RK817 的 HP 输出经外部功放；vendor HAL 的 SPK 路径改成 HP。
4. 按键：A/B 交换、gammapad；摇杆方向正确。
5. RetroArch：中文字体/语言自动补（userdata 重置后由 vendor 启动脚本写入）。
6. 3DS：azahar-nano，Mali Vulkan；core 和 AdrenoTools hooks 开机从 p3 复制到 /data；Daijishō 的 Nintendo 3DS 平台首次开机自动写入。
7. DS：drastic-nano（nano 壳）；Daijishō 仍可用 DraStic。
8. 存储/MTP：保留完整 vendor 媒体库，c2/rockit 正常，MTP 能显示目录。

## 镜像

在 Releases 下载 `pocketAis-GammaOS-20261027-v24f.img.xz` 和 `SHA256SUMS-v24f.txt`。

刷写：xz 解压得到 raw 镜像，用 Rufus 的 DD 模式写入 TF 卡。首次启动 userdata 会重置。

首次刷机后：

1. 3DS 平台会自动出现在 Daijishō 的第一个位置。
2. 把 3DS ROM 放回 `ROMs/n3ds`。
3. 在 3DS 平台按一次 **+ Paths**，选 `ROMs/n3ds`。这是 Android SAF 的目录授权，只能由界面授予；授权一次后一直有效。
4. DS 游戏从 GammaOS Nano 壳启动。

3DS 的平台/播放器由镜像内的种子数据库和首次开机脚本写入；脚本会等 Daijishō 真正建好数据库后再动手，不依赖固定的 40 秒窗口。

## 3DS 说明

- 3DS 只走 Vulkan；OpenGL ES 在 Mali-G52 上不可用。
- azahar-nano 的 core 必须和 4 个 AdrenoTools hook 库在同一目录：`libhook_impl.so`、`libmain_hook.so`、`libfile_redirect_hook.so`、`libgsl_alloc_hook.so`。本移植把它们放在 `/data`，由 p3 的 `/azahar` 在开机时复制，并设置 `persist.gammaos.azahar_nano.core`。
- core 放在 `/data` 还有第二个更硬的理由：core 有 38 MB，而 `/system` 只剩约 14 MB，根本塞不进去。`/vendor` 也不行——软链会被 linker 以 realpath 不在 permitted paths 拒绝。
- 上游 RG52mini v1.14 里的 Turnip/Adreno 610 驱动包与 Mali 无关，不使用。
- 更多细节见 `docs/3ds.md`。

## 与 NGP45HT 的差异

Pocket AIS 和 NGP45HT 是两台机器，直接套用会出问题：

- **外部功放接法不同。** Pocket AIS 是 `hp2extamplifier` + `hp-ctl-gpios`，功放挂在 RK817 的 HP 路径上，所以 `patch_audio_hal.py` 把 HAL 的 `SPK` 改成 `HP` 才有声。NGP45HT 是 `spk-ctl-gpios = <&gpio0 RK_PA7>`，功放挂在 SPK 路径上——套用这个补丁会让功放 GPIO 不再被拉起，反而失能。
- **面板时序不同。** 两机的 panel-init-sequence 完全一致（2393 字节，md5 `e6cb420c…`），分辨率同为 1024x768，但时序参数不同：本仓 61.0 MHz / hfp 90 / hs 80 / hbp 80（约 60.8 Hz），NGP45HT 52.134144 MHz / hfp 32 / hs 20 / hbp 20（约 61.7 Hz）。

### NGP45HT v26 追加修正

- **3DS 默认大屏布局**：镜像种入 `layout_option=2` 的默认 `config.ini`，避免首次启动说明在下屏、上屏黑屏；游戏运行中长按 Back 2 秒退出。
- **Daijisho 返回键助手**：修 Daijisho 1.8.1 游戏列表里 B/Back 单按不返回的问题，只在 Library 页补键。
- **Daijisho 3DS 平台种子**：如果用户自己装了 Daijisho，开机服务会自动补 Nintendo 3DS 平台和 azahar-nano player（不覆盖现有库）；ROM 目录仍需手动 + Paths 授权。
- **WiFi 看门狗 v2**：AIC8800DC USB 假死后按“WiFi 栈 → USB 重新枚举 → 重载驱动”恢复，替换 vendor 里的 v1。
- **手柄拼音 IME**：开源离线拼音输入法 [ngp-pinyin-ime](https://github.com/llj503/ngp-pinyin-ime)，10×4 手柄网格、约 12 万词条；镜像预装并优先作为默认 IME，AOSP 保留回退。

实现和路径见 [docs/ngp45ht-hotfixes.md](docs/ngp45ht-hotfixes.md)。

## 构建

`image_build/` 里是这台机器上实际使用的脚本，需要在 WSL 下用 `debugfs`、`mtools`、`xz`。脚本开头的 `G=/mnt/f/pocketAis/gammaos` 是本机路径，按自己的目录改。

需要的上游材料：

- `GammaOSCore-NGP45HT-20261026-v24.img`（系统、vendor、内核、initrd）
- `GammaOSCore-RG52Mini-20261025-2119-ota.zip`（v1.14：azahar-nano、AzaharSf、core/hooks、WiFi 驱动/固件）
- Pocket AIS 的 p3 启动文件（本仓库 `p3/` 已带 DTB、logo、extlinux）

大致顺序：

1. 从 v24 镜像取出 p4 system、p5 vendor、p3 启动分区。
2. `build_p4.sh`：写入 3DS 前端、core 相关文件、AzaharSf。
3. `build_p5.sh`：写入音频 HAL、AIC8800 SDIO 驱动/固件、AB 属性。
4. `make_p3.sh`：替换 DTB/logo/extlinux，加入 core 和 hooks。
5. `build_v24f.sh`：写入 rc、开机脚本、种子数据库，按分区偏移组装。
6. `xz` 压缩并生成 SHA256。

分区偏移：p3 16 MiB（99 MiB）、p4 116 MiB（3400 MiB）、p5 3516 MiB（254.7 MiB）。

## 来源

- 官方 GammaOS Next NGP45HT v24 镜像：系统、vendor、kernel、initrd。
- RG52mini v1.14：3DS/DS nano、azahar 前端与 core、AdrenoTools hooks、Daijishō 3DS 平台定义、AIC8800D80 SDIO 驱动/固件。
- 3DS 模拟器：[azahar-emu](https://github.com/azahar-emu/azahar)、GammaOS Next（TheGammaSqueeze）、[libadrenotools](https://github.com/bylaws/libadrenotools)。
- Pocket AIS 的 DTB/logo/extlinux 来自 [dArkOS-PokectAis](https://github.com/llj503/dArkOS-PokectAis) 的移植。
- Daijishō 3DS 平台/播放器来自 RG52mini v1.14 的 `platforms.sql`，种子库不含任何个人游戏记录。

## 已知问题

1. 蓝牙未启用：vendor 只有 SV6160 的 BT HAL，AIC8800 的 BT 需要另外适配。
2. Windows 上 MTP 偶发驱动 Code 19；更新/重装 MTP 驱动后正常。
3. 镜像不含用户数据、ROM、存档；首次刷机全部重置。
4. + Paths 是 Android SAF 限制，不能由脚本预授权。
