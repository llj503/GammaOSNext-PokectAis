# 3DS on Pocket AIS

## 为什么能跑

Pocket AIS 和 RG52mini 是同一套 RK3562/Mali-G52 硬件：vendor 的 `libGLES_mali.so`、`vulkan.rk3562.so`、`libvulkan.so`、`ld.config.26.txt` 甚至 linker64 都逐字节相同。上游 v1.14 的 3DS 只走 Vulkan，并且把 OpenGL ES 从菜单里去掉了（Mali-G52 的 GLES 路径在 azahar 下会挂）。

上游的 `gammaos-turnip-adreno-610` 驱动包是给其它 Adreno 610 设备的，Mali 用不到。

## 两个关键点

1. `libazahar-nano-core.so` 要在 `/system/lib64` 或其它默认命名空间允许的路径。放到 `/vendor` 再用软链会被 linker 拒绝（realpath 不在 permitted paths）。
2. azahar 即使选“系统驱动”也会经过 AdrenoTools，需要 4 个 hook 库：
   - `libhook_impl.so`
   - `libmain_hook.so`
   - `libfile_redirect_hook.so`
   - `libgsl_alloc_hook.so`

前端的 hook 库目录取自 **core 所在目录**。上游把 core 和 hooks 都放在 `/system/lib64`；本移植把 core 放到 `/data`，所以 hooks 也必须在 `/data`，由 p3 的 `/azahar` 在开机时复制，并设置 `persist.gammaos.azahar_nano.core=/data/azahar-core.so`。

## 开机和平台

- `azahar-nano-setup.sh`：从 `/mnt/boot/azahar` 复制 core 和 hooks 到 `/data`。
- `azahar-nano.rc`：post-fs-data 挂 p3，启动 3DS 的三个触发点都会先执行上面的脚本。
- `azahar-seed-daijisho.sh`：首次开机等 Daijishō 的数据目录和数据库出现，停掉桌面，换入带 3DS 平台的种子库，修正权限，重启桌面。v24e 的 40 秒等待太短，v24f 改成最多等 1 小时。

## ROM 目录

`+ Paths` 是 Android SAF 的目录授权。shell 的 `am --grant-persistable-uri-permission` 和 `appops MANAGE_EXTERNAL_STORAGE` 都不能替代用户选择；系统不会记录授权。用户点一次后，授权持久保存，ROM 目录会正常扫描。

## 实测

- Vulkan 1.3.283，Mali 扩展完整。
- 菜单/轻场景 59.9 fps；标题动画约 44–50 fps（stock 频率，CPU 2.0GHz / GPU 900MHz）。
- 3DS core 37,943,712 B；hooks 共约 290 KB。

## NGP45HT 追加

- 首次启动说明画在下屏；旧镜像默认 `layout_option=1`（只显示上屏）会像黑屏。v26 构建种入 `layout_option=2` 的默认配置，旧镜像可手动改，详见 `ngp45ht-hotfixes.md`。
- 游戏运行中退出：**长按 Back 约 2 秒**（单按/双击不退）。
- Daijisho 游戏列表的 Back/B 返回由 `ngp_back_helper` 修正。
