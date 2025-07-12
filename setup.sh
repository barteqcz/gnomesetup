#!/bin/bash

set -e

cat <<'EOF' | sudo tee /usr/local/bin/themeswitcher.sh > /dev/null
#!/bin/bash

GTK_THEME_LIGHT="adw-gtk3"
GTK_THEME_DARK="adw-gtk3-dark"

ICON_THEME_LIGHT="Papirus-Light"
ICON_THEME_DARK="Papirus-Dark"

apply_theme() {
    scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

    if [[ "$scheme" == "'prefer-dark'" ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_DARK"
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_DARK"
    else
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_LIGHT"
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_LIGHT"
    fi
}

apply_theme

gsettings monitor org.gnome.desktop.interface color-scheme | while read -r _; do
    apply_theme
done
EOF

sudo chmod 755 /usr/local/bin/themeswitcher.sh

cat <<'EOF' | sudo tee /usr/local/bin/gtkcssupdater.sh > /dev/null
#!/bin/bash

gtk_files="$HOME/.config/gtk-3.0/gtk.css $HOME/.config/gtk-4.0/gtk.css"

update_gtk_css() {
  choosen_color=$(gsettings get org.gnome.desktop.interface accent-color | tr -d "'")

  mkdir -p "$HOME/.config/gtk-4.0"
  echo ":root { --accent-bg-color: var(--accent-$choosen_color); }" > "$HOME/.config/gtk-4.0/gtk.css"

  mkdir -p "$HOME/.config/gtk-3.0"
  cat <<EOF_CSS > "$HOME/.config/gtk-3.0/gtk.css"
@define-color accent_blue #3584e4;
@define-color accent_teal #2190a4;
@define-color accent_green #3a944a;
@define-color accent_yellow #c88800;
@define-color accent_orange #ed5b00;
@define-color accent_red #e62d42;
@define-color accent_pink #d56199;
@define-color accent_purple #9141ac;
@define-color accent_slate #6f8396;
@define-color accent_bg_color @accent_$choosen_color;
EOF_CSS
}

update_gtk_css

gsettings monitor org.gnome.desktop.interface accent-color | while read -r _; do
  update_gtk_css
done
EOF

sudo chmod 755 /usr/local/bin/gtkcssupdater.sh

cat <<EOF | sudo tee /etc/systemd/user/themeswitcher.service > /dev/null
[Unit]
Description=GNOME GTK3 theme switcher
After=graphical-session.target

[Service]
ExecStart=/usr/local/bin/themeswitcher.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

sudo chmod 644 /etc/systemd/user/themeswitcher.service

cat <<EOF | sudo tee /etc/systemd/user/gtkcssupdater.service > /dev/null
[Unit]
Description=Theme CSS adjuster
After=graphical-session.target

[Service]
ExecStart=/usr/local/bin/gtkcssupdater.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

sudo chmod 644 /etc/systemd/user/gtkcssupdater.service

sudo systemctl --global enable themeswitcher.service
sudo systemctl --global enable gtkcssupdater.service

echo "Setup completed successfully."
