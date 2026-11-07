# GammaOSNext-PokectAis

GammaOS Next（Android 14 / LineageOS 21）在 Pocket AIS（XIFAN NGP45HT，RK3562）上的移植。

当前拼装版本 v43：桌面全面切到 LANGOS 3.7.1，并对齐 NGP45HT v42 的可用修正。
逐项移植判断见 [docs/v43-pocketais.md](docs/v43-pocketais.md)。

## 已实现

1. 屏幕：1024x768 DSI，正立；使用 v24 官方的 WM 旋转修复。
2. WiFi：AIC8800D80 SDIO，RG52mini 驱动/固件；附 SDIO 版看门狗。
3. 音频：RK817 的 HP 输出经外部功放；vendor HAL 的 SPK 路径改成 HP。
4. 按键：A/B 交换、gammapad；摇杆方向正确；手柄 re-hid 假死开机自愈。
5. 桌面：LANGOS 3.7.1 内置为默认 home，开机自动设 home 并授予存储权限。
6. 输入法：内置手柄拼音 IME（ngp-pinyin-ime），AOSP/LeanKey 保留回退。
7. RetroArch：简体中文 + 单文件 CJK ttf 字体，开机自动补；只填用户没设过的项。
8. 3DS：azahar-nano，Mali Vulkan；core 和 AdrenoTools hooks 开机从 p3 复制到 /data（按大小升级）。LANGOS 扫到 n3ds ROM 即显示平台。
9. DS：drastic-nano（nano 壳）。
10. PS2：首装 NetherSX2 / ARMSX2（必须 legacy armv8.0），可正常卸载。
11. 存储/MTP：保留完整 vendor 媒体库，c2/rockit 正常，MTP 能显示目录。

## 镜像

已发布的 v24f 镜像仍在 Releases：`pocketAis-GammaOS-20261027-v24f.img.xz` 和
`SHA256SUMS-v24f.txt`。v43 由本仓库的 `image_build/build_v43_pocketais.sh` 从
v24f 镜像拼出，尚未发布。

刷写：xz 解压得到 raw 镜像，用 Rufus 的 DD 模式写入 TF 卡。首次启动 userdata 会重置。

首次刷机后：

1. 桌面是 LANGOS，ROM 放在 `/storage/emulated/0/ROMs/<平台>`，LANGOS 直接扫描，
   不需要 SAF 授权。
2. 3DS ROM 放回 `ROMs/n3ds`，PS2 放 `ROMs/ps2` 等。
3. DS 游戏从 GammaOS Nano 壳启动。
4. 如果自己装 Daijishō，3DS 平台仍需在界面上按一次 **+ Paths** 授权；LANGOS
   不需要这一步。

v24f 及更早的镜像以 Daijishō 为桌面，3DS 平台由种子数据库和首次开机脚本写入。
v43 起这些 Daijishō 服务变成空转（等不到数据库），无害保留。

## 3DS 说明

- 3DS 只走 Vulkan；OpenGL ES 在 Mali-G52 上不可用。
- azahar-nano 的 core 必须和 4 个 AdrenoTools hook 库在同一目录：`libhook_impl.so`、`libmain_hook.so`、`libfile_redirect_hook.so`、`libgsl_alloc_hook.so`。本移植把它们放在 `/data`，由 p3 的 `/azahar` 在开机时复制，并设置 `persist.gammaos.azahar_nano.core`。
- 为什么 core 不直接留在 `/system`：core 有 38 MB，v24f 的 `/system` 只剩约 14 MB。v43 回收了 p4 分区里约 397 MiB 的空隙，那部分空间是给 LANGOS、IME 和模拟器 APK 的，core 仍按上游做法从 p3 搬到 `/data`。`/vendor` 也不行——软链会被 linker 以 realpath 不在 permitted paths 拒绝。
- 复制按大小比对：镜像里的 core 更新后，`/data` 上的旧文件会被替换，不会因为“文件已存在”而一直用旧版。
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

### v43：从 NGP45HT v42 移植

| 项 | 本机处理 |
| --- | --- |
| LANGOS 3.7.1 默认桌面 | 移植，放 p4；`rom_root` 指向内置存储 `/storage/emulated/0/ROMs` |
| 手柄拼音 IME | 移植，并修正 v24f 留下的 `persist.rg52.ime` 旧值 |
| 模拟器首装 | NetherSX2、Azahar 官方版、ARMSX2（legacy armv8.0） |
| 3DS core 升级 | 改为按大小比对，镜像升级后 `/data` 不再留旧 core |
| RetroArch 中文字体 | 改用单文件 ttf；`.ttc` 是无效的，相关脚本已删除 |
| WiFi 看门狗 | **重写为 SDIO 版**，USB 版在本机只会空转 |
| 鼠标模式 Toast / 关反色闪烁 | 移植 |
| 回收 p4 分区空隙 | 新增；文件系统 3003 MiB → 3400 MiB，不改 GPT |
| HDMI / LED / adc-keys / EEROMS | 跳过，本机没有对应硬件 |
| SPK 音频补丁 / DTB / 面板时序 | **禁止**，会关功放或弄坏屏幕 |

LANGOS、IME 和三个模拟器 APK 约 152 MiB。Pocket AIS 的 p5 只有 254.7 MiB 且已
用满 248 MiB，不像 NGP45HT 那样能扩 p5，所以这些 payload 放 p4。p4 的 ext4
文件系统当初只建到 3003 MiB，分区本身是 3400 MiB，`build_v43_pocketais.sh` 用
`resize2fs` 把这段约 397 MiB 的空隙收回来（实测扩后空 465 MiB，装完 payload
还剩 326 MiB）；不动 GPT，也不碰 p5..p9。

逐项理由、实测数据和被跳过的硬件证据见 [docs/v43-pocketais.md](docs/v43-pocketais.md)。

## 构建

`image_build/` 里是这台机器上实际使用的脚本，需要在 WSL / Linux 下用 `debugfs`、`mtools`、`sgdisk`、`e2fsprogs`。脚本开头的 `G=/mnt/f/pocketAis/gammaos` 是本机路径，按自己的目录改。

需要的上游材料：

- `GammaOSCore-NGP45HT-20261026-v24.img`（系统、vendor、内核、initrd）
- `GammaOSCore-RG52Mini-20261025-2119-ota.zip`（v1.14：azahar-nano、AzaharSf、core/hooks、WiFi 驱动/固件）
- Pocket AIS 的 p3 启动文件（本仓库 `p3/` 已带 DTB、logo、extlinux）
- 拼 v43 时还需要一个 Pocket AIS v24f（或更新）镜像作为 base

v24f 及更早的大致顺序：

1. 从 v24 镜像取出 p4 system、p5 vendor、p3 启动分区。
2. `build_p4.sh`：写入 3DS 前端、core 相关文件、AzaharSf。
3. `build_p5.sh`：写入音频 HAL、AIC8800 SDIO 驱动/固件、AB 属性。
4. `make_p3.sh`：替换 DTB/logo/extlinux，加入 core 和 hooks。
5. `build_v24f.sh`：写入 rc、开机脚本、种子数据库，按分区偏移组装。
6. `xz` 压缩并生成 SHA256。

v43：

```sh
cd image_build
./build_v43_pocketais.sh /path/to/pocketAis-v24f.img pocketais-v43.img
```

脚本复制 base（**不改原镜像**），从 GPT 现读偏移并检查 p4 空闲量；不够 payload +
100 MiB 余量就先 `e2fsck -fy` 再 `resize2fs` 到 p4 现有分区大小（回收约
397 MiB 的历史空隙），然后写入 p4 / p5 的内容。整个过程中 GPT 不变，p5..p9
不动。若换了已经回收过空隙的 base 而空间仍不够，脚本会直接报错退出，不会去改
分区表。

`build_v43_pocketais.sh` 从 GPT 读分区布局，不写死偏移；`build_v24f.sh` 等旧脚本里仍是
p3 16 MiB（99 MiB）、p4 116 MiB（3400 MiB）、p5 3516 MiB（254.7 MiB）。

## 来源

- 官方 GammaOS Next NGP45HT v24 镜像：系统、vendor、kernel、initrd。
- RG52mini v1.14：3DS/DS nano、azahar 前端与 core、AdrenoTools hooks、Daijishō 3DS 平台定义、AIC8800D80 SDIO 驱动/固件。
- 3DS 模拟器：[azahar-emu](https://github.com/azahar-emu/azahar)、GammaOS Next（TheGammaSqueeze）、[libadrenotools](https://github.com/bylaws/libadrenotools)。
- Pocket AIS 的 DTB/logo/extlinux 来自 [dArkOS-PokectAis](https://github.com/llj503/dArkOS-PokectAis) 的移植。
- Daijishō 3DS 平台/播放器来自 RG52mini v1.14 的 `platforms.sql`，种子库不含任何个人游戏记录。
- LANGOS 3.7.1 前端、手柄拼音 IME [ngp-pinyin-ime](https://github.com/llj503/ngp-pinyin-ime)、
  模拟器包 NetherSX2 / Azahar 官方版 / ARMSX2 由本仓 `image_build/` 直接携带。

## 已知问题

1. 蓝牙未启用：vendor 只有 SV6160 的 BT HAL，AIC8800 的 BT 需要另外适配。
2. Windows 上 MTP 偶发驱动 Code 19；更新/重装 MTP 驱动后正常。
3. 镜像不含用户数据、ROM、存档；首次刷机全部重置。
4. Daijishō 的 + Paths 是 Android SAF 限制，不能由脚本预授权；LANGOS 不需要。
5. 内置 3DS 前端 `com.gammaos.azaharsf` 是 `sharedUserId=android.uid.system` 的
   system app，不能重签也不能移出 `/system/app`。不想要它：建
   `/data/ngp/disable-internal-3ds` 再重启。
6. ARMSX2 必须用 legacy armv8.0 包；armv8.2 包在 Cortex-A53 上读游戏序列号时
   SIGILL。
7. 模拟器装进 `/data/app` 后可正常卸载；本机 `pm list packages -u` 不保留卸载
   记录，所以用 `/data/ngp/emu-installed/<包名>` 标记。删标记再重启即恢复。
8. v24f 继承的 `ngp-seed-daijisho` / `ngp-back-helper` 在 LANGOS 桌面下是空转的，
   无害保留。
