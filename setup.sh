#!/bin/bash
set -e

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

echo "Done."
