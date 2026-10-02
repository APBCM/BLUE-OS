#!/usr/bin/env bash
set -euo pipefail
state="$HOME/.config/blue-os/look-applied"
if [[ ! -e "$state" ]]; then
    mkdir -p "$(dirname "$state")" "$HOME/.config/gtk-3.0" "$HOME/.config/xfce4/terminal"
    xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s Adwaita-dark
    xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s Papirus-Dark
    xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s 'Inter 10'
    while read -r property; do
        xfconf-query -c xfce4-desktop -p "$property" -s /usr/share/backgrounds/blue-os/wallpaper.svg
    done < <(xfconf-query -c xfce4-desktop -lv | awk '$1 ~ /\/last-image$/ {print $1}')
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -n -t string -s /usr/share/backgrounds/blue-os/wallpaper.svg
    xfconf-query -c xfce4-screensaver -p /saver/enabled -n -t bool -s true
    xfconf-query -c xfce4-screensaver -p /lock/saver-activation/delay -n -t int -s 5
    cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
@define-color theme_selected_bg_color #00A8FF;
@define-color theme_selected_fg_color #0B132B;
EOF
    cat > "$HOME/.config/xfce4/terminal/terminalrc" <<'EOF'
[Configuration]
ColorBackground=#0B132B
ColorForeground=#EAF8FF
ColorCursor=#00A8FF
FontName=JetBrains Mono 11
EOF
    touch "$state"
fi
if ! pgrep -u "$(id -u)" -x plank >/dev/null; then plank >/dev/null 2>&1 & fi
