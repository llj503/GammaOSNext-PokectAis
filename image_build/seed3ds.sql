CREATE TEMP TABLE IF NOT EXISTS rg52_m (k TEXT PRIMARY KEY, v INTEGER);
BEGIN;
INSERT OR REPLACE INTO rg52_m VALUES ('base', (SELECT COALESCE(MAX(id), 0) FROM PlayerEntity)), ('add', (SELECT COUNT(*) = 0 FROM PlatformEntity WHERE unique_id = '3ds'));
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.com.gammaos.azaharsf', 1, '3ds - azahar-nano (GammaOS)', 'azahar-nano, the 3DS emulator built into GammaOS. Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf, zcci, zcxi.', '-n com.gammaos.azaharsf/.AzaharSfActivity
 -a android.intent.action.MAIN
 -e ROM {file.path}
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf|zcci|zcxi)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.azahar', 1, '3ds - azahar', 'Supported extensions: cci, cxi, zcci, zcxi.', '-n io.github.lime3ds.android/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:cci|cxi|zcci|zcxi|3ds)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.azahar.vanilla', 1, '3ds - azahar (vanilla)', 'Supported extensions: cci, cxi, zcci, zcxi.', '-n org.azahar_emu.azahar/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:cci|cxi|zcci|zcxi|3ds)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.io.github.azaharplus.android', 1, '3ds - azahar plus', 'Supported extensions: cci, cxi, zcci, zcxi.', '-n io.github.azaharplus.android/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|cci|cxi|zcci|zcxi)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.io.github.borked3ds.android', 1, '3ds - Borked 3DS', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n io.github.borked3ds.android/.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.org.citra.citra_emu', 1, '3ds - Citra Nightly', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n org.citra.citra_emu/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.org.citra.citra_emu.canary', 1, '3ds - Citra Canary', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n org.citra.citra_emu.canary/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.org.gamerytb.lemonade.canary', 1, '3ds - Lemonade Alpha', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n org.gamerytb.lemonade.canary/org.citra.citra_emu.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.io.github.lime3ds.android', 1, '3ds - Lime 3DS', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n io.github.lime3ds.android/.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.io.github.mandarine3ds.mandarine', 1, '3ds - Mandarine', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n io.github.mandarine3ds.mandarine/.activities.EmulationActivity
 -a android.intent.action.VIEW
 -d {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.com.antutu.ABenchMark', 1, '3ds - org.citra.emu - antutu', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.antutu.ABenchMark/org.citra.emu.ui.EmulationActivity
 -a android.intent.action.VIEW
 -e GamePath {file.path}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.com.antutu.ABenchMark', 1, '3ds - org.citra.emu - storage access antutu', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.antutu.ABenchMark/org.citra.emu.ui.EmulationActivity
 -a android.intent.action.VIEW
 -e GamePath {file.uri}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.org.citra.emu', 1, '3ds - org.citra.emu', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n org.citra.emu/org.citra.emu.ui.EmulationActivity
 -a android.intent.action.VIEW
 -e GamePath {file.path}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.org.citra.citra_emu', 1, '3ds - org.citra.citra_emu', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n org.citra.citra_emu/org.citra.citra_emu.ui.EmulationActivity
 -a android.intent.action.VIEW
 -e GamePath {file.path}
 --activity-clear-task
 --activity-clear-top
', 0, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra64.citra', 1, '3ds - RetroArch 64 - citra', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch.aarch64/cores/citra_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch.aarch64
  -e APK /data/app/com.retroarch.aarch64-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch.aarch64/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra64.panda3ds', 1, '3ds - RetroArch 64 - panda3ds', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch.aarch64/cores/panda3ds_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch.aarch64
  -e APK /data/app/com.retroarch.aarch64-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch.aarch64/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra64.azahar', 1, '3ds - RetroArch 64 - azahar', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch.aarch64/cores/azahar_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch.aarch64
  -e APK /data/app/com.retroarch.aarch64-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch.aarch64/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra.citra', 1, '3ds - RetroArch - citra', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch/cores/citra_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch
  -e APK /data/app/com.retroarch-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra.panda3ds', 1, '3ds - RetroArch - panda3ds', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch/cores/panda3ds_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch
  -e APK /data/app/com.retroarch-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlayerEntity (unique_id, player, name, description, am_start_arguments, kill_package_processes, kill_package_processes_warning, accepted_filename_regex, extra) SELECT '3ds.ra.azahar', 1, '3ds - RetroArch - azahar', 'Supported extensions: 3ds, 3dsx, app, axf, cci, cxi, elf.', '-n com.retroarch/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch/cores/azahar_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch/files/retroarch.cfg
  -e IME com.android.inputmethod.latin/.LatinIME
  -e DATADIR /data/data/com.retroarch
  -e APK /data/app/com.retroarch-1/base.apk
  -e SDCARD /storage/emulated/0
  -e EXTERNAL /storage/emulated/0/Android/data/com.retroarch/files
  --activity-clear-task
  --activity-clear-top', 1, 1, '^(.*)\.(?:3ds|3dsx|app|axf|cci|cxi|elf)$', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
INSERT INTO PlatformEntity (unique_id, name, shortname, description, is_visible, scrape_preview_media, wallpaper_path, thumbnail_path, color_theme, color_on_theme, accept_filename_regex, default_player_id, player_id_list, scraper_source_list, box_art_aspect_ratio_id, use_custom_box_art_aspect_ratio, custom_box_art_aspect_ratio, screen_aspect_ratio_id, use_custom_screen_aspect_ratio, custom_screen_aspect_ratio, items_sync_tree_uri_list, retro_achievements_console_id_list, extra) SELECT '3ds', 'Nintendo 3DS', '3ds', NULL, 1, 1, NULL, NULL, NULL, NULL, '^(?!(?:\._|\.|Scan_for_new_games\.).*).*$', (SELECT id FROM PlayerEntity WHERE id > (SELECT v FROM rg52_m WHERE k = 'base') ORDER BY id LIMIT 1 OFFSET 0), (SELECT json_group_array(id) FROM (SELECT id FROM PlayerEntity WHERE id > (SELECT v FROM rg52_m WHERE k = 'base') ORDER BY id)), '["LIBRETRO:Nintendo - Nintendo 3DS","LIBRETRO:Nintendo - Nintendo 3DS (Digital)"]', 0, 1, '8:7', 0, 0, NULL, '["content://com.android.externalstorage.documents/tree/primary%3AROMs%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3Aroms%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3A3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3Aroms%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3A3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3Aroms%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3A3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3Aroms%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3A3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3Aroms%2F3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3A3ds","content://com.android.externalstorage.documents/tree/primary%3AROMs%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3Aroms%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3An3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3Aroms%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3An3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3Aroms%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3An3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3Aroms%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3An3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3Aroms%2Fn3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3An3ds","content://com.android.externalstorage.documents/tree/primary%3AROMs%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3Aroms%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000001%3Anintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3Aroms%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000002%3Anintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3Aroms%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000003%3Anintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3Aroms%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000004%3Anintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3Aroms%2Fnintendo3ds","content://com.android.externalstorage.documents/tree/00000000-0000-0000-0000-000000000005%3Anintendo3ds"]', '[62]', '' WHERE (SELECT v FROM rg52_m WHERE k = 'add');
UPDATE PlatformEntity SET wallpaper_path = '/data/user/0/com.magneticchen.daijishou/files/platform_wallpapers/' || id || '.png' WHERE unique_id = '3ds' AND wallpaper_path IS NULL;
COMMIT;
COMMIT;
