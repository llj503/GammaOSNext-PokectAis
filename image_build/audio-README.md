# GammaOS 音频 HAL 路由补丁

## 问题

Pocket AIS 的扬声器接在 **RK817 的 HP 输出 + 外部功放**上（DTB 中
`use-ext-amplifier`、`hp2extamplifier`、`hp-ctl-gpios`），不是 SPK 输出。
dArkOS 的 AisOS 参考配置也把扬声器和耳机都设置为 `Playback Path=HP`。

NGP45HT 的 Android vendor HAL **不读取** `/vendor/etc/mixer_paths.xml`。它使用
编译进 `audio.primary.rk30board.so` 的默认路由表，启动日志会显示：

```text
Can not get config table for sound card0 rockchiprk817, so get default config table.
```

默认的 speaker normal 路由只设置：

```text
Playback Path = SPK
```

在这块板子上 SPK 没有接扬声器，因此视频/游戏/应用全部无声；手工执行
`tinymix "Playback Path" 3`（HP）后声音正常，`tinyplay` 测试音也能听到。

## 补丁

把 HAL 内置路由表中的独立字符串 `SPK` 改成 `HP`。两个 HAL 都改：

| 文件 | 文件内偏移 | 原值 | 改后值 | 原始 SHA-256 | 补丁后 SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `lib/hw/audio.primary.rk30board.so` | `0xA576` | `SPK` | `HP\0` | `e3b529c9be24b50b7d87e022412541aaf5c5f57d0acd975d84f528f6eb885b6e` | `01817b644c40ba8eb3a720ce50f2a08b78c5803a5e9144d60a3435f6d6b4b01d` |
| `lib64/hw/audio.primary.rk30board.so` | `0xC37B` | `SPK` | `HP\0` | `8d0b238478ef105fb98a1666507ef712204f81217efb906808e4a26e3eb41ef6` | `e327017b3e0414b71b859e0d9e3c972f433e3d789d2ae5ae65fb3b8617834728` |

实际被 `android.hardware.audio.service` 加载的是 **32 位** HAL（映射路径为
`/vendor/lib/hw/...`）；64 位文件也打补丁，保证镜像一致。

改完后 HAL 的 speaker normal / incall / voip 路由都会选择 HP：

```text
Playback Path = HP
DAC Playback Volume = 199 199   （音量策略决定，数值可能变化）
HP Output Gain = 0
Speaker Switch = On
Headphone Switch = Off
```

待机时 `Playback Path` 回到 `OFF` 是正常的；开始播放后应变成 `HP`。

## 使用

### 对已挂载/解包的 vendor 分区

```bash
python3 patch_audio_hal.py /path/to/vendor
```

脚本按相对路径查找 `lib/hw/...` 和 `lib64/hw/...`，校验原始 SHA-256 后，用
`r+b` 在**原位置**写入 3 字节，不重写整个文件（vendor 分区接近满时也可用）。
已经打过补丁的文件会被识别并跳过。

只检查、不写入：

```bash
python3 patch_audio_hal.py --check /path/to/vendor
```

### 对当前设备

1. 备份两个 HAL 文件。
2. 如需写入 `/vendor`，先确认可以安全地 remount rw；空间不足时不要整文件覆盖，
   用脚本的原位写入。
3. 停/启 vendor audio HAL，或重启：

```bash
setprop ctl.stop vendor.audio-hal
setprop ctl.start vendor.audio-hal
```

4. 播放视频/游戏，检查：

```bash
tinymix | grep "Playback Path"
cat /sys/kernel/debug/gpio | grep hp-ctl
```

播放时应看到 `Playback Path: HP`，`gpio-115 ... hp-ctl ... out hi`（外部功放使能）。
`tinyplay` 直接走 ALSA，绕过 Android HAL，不能单独用来验证应用音频路由。

### 最终镜像

`pocketAis-GammaOS-20261021-v1.img` 的 p5 已经包含这两个补丁；日常刷机不需要再执行
本脚本。脚本用于重新打包或维护时复现补丁。若手工修改 p5 的 ext4 镜像，请用
`debugfs`/块级原位写入，不要依赖整个文件覆盖（vendor 分区可用空间很小）。

## 备注

- `/vendor/etc/mixer_paths.xml` 中的 HP 设置对这套 HAL 不生效；保留它无害，但不要
  再试图通过它修复路由。
- 这个补丁只改路由值，不改 DAC/音量/功放 GPIO 逻辑；外部功放仍由 codec 的 HP 路径
  控制。
- 若上游 HAL 更新导致 SHA-256 不一致，脚本会拒绝写入；此时需要重新定位 HAL 中的
  独立 `SPK` 字符串和路由表偏移，不要盲目按旧偏移打补丁。
