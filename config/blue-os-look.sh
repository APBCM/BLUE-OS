#!/usr/bin/env bash
set -euo pipefail
state="$HOME/.config/blue-os/look-applied"
[[ ! -e "$state" ]] || exit 0
mkdir -p "$(dirname "$state")" "$HOME/.config/gtk-3.0" "$HOME/.local/share/color-schemes" "$HOME/.local/share/konsole"
cat > "$HOME/.local/share/color-schemes/BlueOS.colors" <<'EOF'
[General]
Name=Blue OS
ColorScheme=BlueOS
shadeSortColumn=true
[Colors:Window]
BackgroundNormal=11,19,43
ForegroundNormal=234,248,255
[Colors:View]
BackgroundNormal=15,27,50
ForegroundNormal=234,248,255
DecorationFocus=0,168,255
DecorationHover=0,168,255
[Colors:Button]
BackgroundNormal=20,39,70
ForegroundNormal=234,248,255
[Colors:Selection]
BackgroundNormal=0,168,255
ForegroundNormal=11,19,43
[Colors:Tooltip]
BackgroundNormal=11,19,43
ForegroundNormal=234,248,255
[WM]
activeBackground=11,19,43
activeForeground=234,248,255
inactiveBackground=20,39,70
inactiveForeground=180,195,210
EOF
cat > "$HOME/.local/share/konsole/BlueOS.colorscheme" <<'EOF'
[General]
Description=Blue OS
Opacity=0.94
[Background]
Color=11,19,43
[Foreground]
Color=234,248,255
[Color1]
Color=0,168,255
EOF
cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
@define-color theme_selected_bg_color #00A8FF;
@define-color theme_selected_fg_color #0B132B;
EOF
kwriteconfig5 --file kdeglobals --group General --key Name BlueOS
kwriteconfig5 --file kdeglobals --group General --key font 'Vazirmatn,10,-1,5,50,0,0,0,0,0'
kwriteconfig5 --file kdeglobals --group Icons --key Theme breeze-dark
kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
kwriteconfig5 --file kdeglobals --group General --key ColorScheme BlueOS
kwriteconfig5 --file kxkbrc --group Layout --key Use true
kwriteconfig5 --file kxkbrc --group Layout --key LayoutList us,ir
kwriteconfig5 --file kxkbrc --group Layout --key VariantList ,
kwriteconfig5 --file kxkbrc --group Layout --key Options grp:alt_shift_toggle
kwriteconfig5 --file kxkbrc --group Layout --key Model pc105
kwriteconfig5 --file plasmarc --group Theme --key name breeze-dark
kwriteconfig5 --file ksplashrc --group KSplash --key Theme org.kde.breeze.desktop
kwriteconfig5 --file konsolerc --group 'Desktop Entry' --key DefaultProfile BlueOS.profile
cat > "$HOME/.local/share/konsole/BlueOS.profile" <<'EOF'
[Appearance]
ColorScheme=BlueOS
Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0
[General]
Name=Blue OS
Parent=FALLBACK/
EOF
plasma-apply-wallpaperimage /usr/share/backgrounds/blue-os/wallpaper.svg || true
touch "$state"
