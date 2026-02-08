#!/bin/bash
set -e

# --- REQUIRE ROOT ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Run with: sudo $0"
  exit 1
fi

echo "Downloading and installing latest adw-gtk3 theme..."

REPO="lassekongo83/adw-gtk3"
DEST="/usr/share/themes"

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Download latest release tar.gz
curl -s https://api.github.com/repos/$REPO/releases/latest \
  | grep "browser_download_url" \
  | grep ".tar.gz" \
  | cut -d '"' -f 4 \
  | wget -i -

# Extract archive
ARCHIVE=$(ls adw-gtk*.tar.gz)
tar -xzf "$ARCHIVE"

# Ownership + permissions
chown -R root:root adw-gtk*
chmod -R 755 adw-gtk*

# Move to /usr/share/themes
mv -a adw-gtk* "$DEST"

# Cleanup
cd /
rm -rf "$TMPDIR"

echo "Theme installed to $DEST"

echo "Creating theme switcher script..."

mkdir -p "$HOME/.local/bin"

cat <<'EOF' > "$HOME/.local/bin/themeswitcher.sh"
#!/bin/bash
set -e

GTK_THEME_LIGHT="adw-gtk3"
GTK_THEME_DARK="adw-gtk3-dark"

ICON_THEME_LIGHT="Papirus-Light"
ICON_THEME_DARK="Papirus-Dark"

apply_theme() {
    scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

    if [[ "$scheme" == "'prefer-dark'" ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_DARK" || true
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_DARK" || true
    else
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_LIGHT" || true
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_LIGHT" || true
    fi
}

update_gtk_css() {
    chosen_color=$(gsettings get org.gnome.desktop.interface accent-color | tr -d "'")

    mkdir -p "$HOME/.config/gtk-4.0"
    echo ":root { --accent-bg-color: var(--accent-$chosen_color); }" \
        > "$HOME/.config/gtk-4.0/gtk.css"

    mkdir -p "$HOME/.config/gtk-3.0"
    cat <<EOY > "$HOME/.config/gtk-3.0/gtk.css"
@define-color accent_blue #3584e4;
@define-color accent_teal #2190a4;
@define-color accent_green #3a944a;
@define-color accent_yellow #c88800;
@define-color accent_orange #ed5b00;
@define-color accent_red #e62d42;
@define-color accent_pink #d56199;
@define-color accent_purple #9141ac;
@define-color accent_slate #6f8396;
@define-color accent_bg_color @accent_$chosen_color;
EOY
}

apply_all() {
    apply_theme
    update_gtk_css
}

apply_all

gsettings monitor org.gnome.desktop.interface color-scheme |
while read -r _; do apply_theme; done &

gsettings monitor org.gnome.desktop.interface accent-color |
while read -r _; do update_gtk_css; done &

wait
EOF

chmod 755 "$HOME/.local/bin/themeswitcher.sh"

echo "Creating systemd user service..."

mkdir -p "$HOME/.config/systemd/user"

cat <<'EOF' > "$HOME/.config/systemd/user/themeswitcher.service"
[Unit]
Description=GNOME theme + accent watcher
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/themeswitcher.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

chmod 644 "$HOME/.config/systemd/user/themeswitcher.service"

systemctl --user enable --now themeswitcher.service

cat <<'EOF' > /usr/local/bin/themeswitcher.sh
#!/bin/bash

sleep 20
iwconfig wlan0 power off
EOF

cat <<'EOF' > /etc/systemd/system/wifi-powersave-off.service
[Unit]
Description=Turn WiFi power saving off at boot.
After=network-online.target

[Service]
ExecStart=/usr/local/bin/wifi-powersave-off.sh

[Install]
WantedBy=default.target
EOF

chmod 644 "/etc/systemd/system/wifi-powersave-off.service"

echo "Done."
