#!/bin/bash
set -e

if [ ! -f /etc/arch-release ]; then
    echo "Error: install.sh is for Arch Linux only." >&2
    exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$TARGET_USER")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing dependencies..."
PKGS=(
    libx11
    libxinerama
    libxft
    fontconfig
    xorg-xsetroot
    xorg-setxkbmap
    pcmanfm
    gvfs
    feh
    maim
    xclip
    j4-dmenu-desktop
    dunst
    libnotify
    lightdm
    lightdm-mini-greeter
    xsettingsd
    fastfetch
    pipewire
    wireplumber
)

sudo pacman -S --needed --noconfirm "${PKGS[@]}"

if ! pacman -Qi picom-ftlabs-git &>/dev/null; then
    echo "==> Installing picom-ftlabs-git..."
    if command -v paru &>/dev/null; then
        paru -S --needed --noconfirm picom-ftlabs-git
    elif command -v yay &>/dev/null; then
        yay -S --needed --noconfirm picom-ftlabs-git
    fi
fi

echo "==> Building suckless tools..."
for tool in vxwm st dmenu; do
    (cd "$SCRIPT_DIR/suckless/$tool" && make clean && make && sudo make install && make clean)
done

echo "==> Installing scripts..."
sudo cp -f "$SCRIPT_DIR/bin/"* /usr/local/bin/
sudo chmod +x /usr/local/bin/dmenu_run /usr/local/bin/screenshot /usr/local/bin/volume /usr/local/bin/vxwm-session

echo "==> Installing configuration files..."
mkdir -p "$USER_HOME/.config/picom" \
         "$USER_HOME/.config/dunst" \
         "$USER_HOME/.config/gtk-3.0" \
         "$USER_HOME/.config/gtk-4.0" \
         "$USER_HOME/.config/fastfetch" \
         "$USER_HOME/.config/xsettingsd" \
         "$USER_HOME/.config/wallpapers" \
         "$USER_HOME/.local/share/file-manager/actions"

cp -f "$SCRIPT_DIR/config/picom/picom.conf" "$USER_HOME/.config/picom/"
cp -f "$SCRIPT_DIR/config/dunst/dunstrc" "$USER_HOME/.config/dunst/"
cp -f "$SCRIPT_DIR/config/gtk-3.0/"* "$USER_HOME/.config/gtk-3.0/"
cp -f "$SCRIPT_DIR/config/gtk-4.0/"* "$USER_HOME/.config/gtk-4.0/"
cp -f "$SCRIPT_DIR/config/fastfetch/"* "$USER_HOME/.config/fastfetch/"
cp -f "$SCRIPT_DIR/config/xsettingsd/"* "$USER_HOME/.config/xsettingsd/"
cp -f "$SCRIPT_DIR/wallpapers/"* "$USER_HOME/.config/wallpapers/"
cp -f "$SCRIPT_DIR/config/xinitrc" "$USER_HOME/.xinitrc"
cp -f "$SCRIPT_DIR/config/file-manager/set-wallpaper.desktop" "$USER_HOME/.local/share/file-manager/actions/"

cat << EOF > "$USER_HOME/.fehbg"
#!/bin/sh
feh --no-fehbg --bg-fill "$USER_HOME/.config/wallpapers/shishkin.jpg"
EOF
chmod +x "$USER_HOME/.fehbg"

chown -R "$TARGET_USER:$TARGET_USER" \
    "$USER_HOME/.config" \
    "$USER_HOME/.local/share/file-manager" \
    "$USER_HOME/.xinitrc" \
    "$USER_HOME/.fehbg"

sudo mkdir -p /etc/lightdm /etc/X11/xorg.conf.d /usr/share/xsessions /usr/share/backgrounds
sudo cp -f "$SCRIPT_DIR/config/lightdm/lightdm.conf" /etc/lightdm/
sudo cp -f "$SCRIPT_DIR/config/lightdm/lightdm-mini-greeter.conf" /etc/lightdm/
sudo cp -f "$SCRIPT_DIR/wallpapers/shishkin.jpg" /usr/share/backgrounds/
sudo chmod 644 /usr/share/backgrounds/shishkin.jpg
sudo cp -f "$SCRIPT_DIR/config/lightdm/vxwm.desktop" /usr/share/xsessions/
sudo cp -f "$SCRIPT_DIR/config/xorg/00-keyboard.conf" /etc/X11/xorg.conf.d/

sudo sed -i "s/^user = .*/user = $TARGET_USER/" /etc/lightdm/lightdm-mini-greeter.conf
sudo sed -i "s/^password-label-text = .*/password-label-text = $TARGET_USER:/" /etc/lightdm/lightdm-mini-greeter.conf

sudo systemctl enable lightdm.service

echo "==> Done!"
