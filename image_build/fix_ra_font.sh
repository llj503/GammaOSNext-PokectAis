#!/system/bin/sh
F=/storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
am force-stop com.retroarch.aarch64
sed -i 's|^user_language = .*|user_language = "12"|' "$F"
sed -i 's|^video_font_path = .*|video_font_path = "/system/fonts/NotoSansCJK-Regular.ttc"|' "$F"
sed -i 's|^ozone_font = .*|ozone_font = "/system/fonts/NotoSansCJK-Regular.ttc"|' "$F"
chown u0_a95:ext_data_rw "$F"
chmod 660 "$F"
grep -nE '^(user_language|video_font_path|ozone_font|menu_driver)' "$F"
