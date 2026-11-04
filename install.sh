#!/bin/bash
set -e

if [ ! -f /etc/arch-release ]; then
    echo "Error: install.sh is for Arch Linux only." >&2
    exit 1
fi

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Starting Installation ===${NC}"

# Detect user and home directory
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
    USER_HOME=$(eval echo "~$SUDO_USER")
else
    TARGET_USER="$USER"
    USER_HOME="$HOME"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Enable multilib in pacman.conf
echo -e "${GREEN}[1/7] Enabling multilib repository...${NC}"
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy
elif ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy
fi

# 2. Install official dependencies
echo -e "${GREEN}[2/7] Installing official packages...${NC}"
OFFICIAL_PKGS=(
    base-devel
    git
    libx11
    libxinerama
    libxft
    fontconfig
    xorg-server
    xorg-xinit
    xorg-xsetroot
    xorg-setxkbmap
    pcmanfm
    gvfs
    feh
    maim
    xclip
    j4-dmenu-desktop
    python
    pipewire
    pipewire-pulse
    wireplumber
    dunst
    libnotify
    lightdm
    lightdm-mini-greeter
    xsettingsd
    fastfetch
)

sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

# 3. Install AUR helper and picom-ftlabs-git
echo -e "${GREEN}[3/7] Installing picom-ftlabs-git...${NC}"
if ! pacman -Qi picom-ftlabs-git &>/dev/null; then
    if pacman -Qi picom &>/dev/null; then
        sudo pacman -Rdd --noconfirm picom
    fi

    if command -v paru &>/dev/null; then
        paru -S --needed --noconfirm picom-ftlabs-git
    elif command -v yay &>/dev/null; then
        yay -S --needed --noconfirm picom-ftlabs-git
    else
        echo "Installing paru..."
        PARU_DIR=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$PARU_DIR"
        (cd "$PARU_DIR" && makepkg -si --noconfirm)
        rm -rf "$PARU_DIR"
        paru -S --needed --noconfirm picom-ftlabs-git
    fi
fi

# 4. Build and install suckless tools
echo -e "${GREEN}[4/7] Compiling and installing suckless tools...${NC}"
for tool in vxwm st dmenu; do
    echo "Building $tool..."
    cd "$SCRIPT_DIR/suckless/$tool"
    make clean
    make
    sudo make install
done

# 5. Install scripts to /usr/local/bin
echo -e "${GREEN}[5/7] Installing scripts to /usr/local/bin...${NC}"
sudo cp -f "$SCRIPT_DIR/bin/"* /usr/local/bin/
sudo chmod +x /usr/local/bin/dmenu_run /usr/local/bin/screenshot /usr/local/bin/volume /usr/local/bin/vxwm-session

# 6. Install configuration files
echo -e "${GREEN}[6/7] Installing configuration files...${NC}"

# User configs
mkdir -p "$USER_HOME/.config/picom"
mkdir -p "$USER_HOME/.config/dunst"
mkdir -p "$USER_HOME/.config/gtk-3.0"
mkdir -p "$USER_HOME/.config/gtk-4.0"
mkdir -p "$USER_HOME/.config/fastfetch"
mkdir -p "$USER_HOME/.config/xsettingsd"
mkdir -p "$USER_HOME/.config/wallpapers"
mkdir -p "$USER_HOME/.local/share/file-manager/actions"

cp -f "$SCRIPT_DIR/config/picom/picom.conf" "$USER_HOME/.config/picom/picom.conf"
cp -f "$SCRIPT_DIR/config/dunst/dunstrc" "$USER_HOME/.config/dunst/dunstrc"
cp -f "$SCRIPT_DIR/config/gtk-3.0/"* "$USER_HOME/.config/gtk-3.0/"
cp -f "$SCRIPT_DIR/config/gtk-4.0/"* "$USER_HOME/.config/gtk-4.0/"
cp -f "$SCRIPT_DIR/config/fastfetch/"* "$USER_HOME/.config/fastfetch/"
cp -f "$SCRIPT_DIR/config/xsettingsd/"* "$USER_HOME/.config/xsettingsd/"
cp -f "$SCRIPT_DIR/wallpapers/"* "$USER_HOME/.config/wallpapers/"
cp -f "$SCRIPT_DIR/config/xinitrc" "$USER_HOME/.xinitrc"
cp -f "$SCRIPT_DIR/config/file-manager/set-wallpaper.desktop" "$USER_HOME/.local/share/file-manager/actions/set-wallpaper.desktop"

# Set default wallpaper
cat << EOF > "$USER_HOME/.fehbg"
#!/bin/sh
feh --no-fehbg --bg-fill "$USER_HOME/.config/wallpapers/shishkin.jpg"
EOF
chmod +x "$USER_HOME/.fehbg"

# Fix ownership
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/picom" "$USER_HOME/.config/dunst" "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0" "$USER_HOME/.config/fastfetch" "$USER_HOME/.config/xsettingsd" "$USER_HOME/.config/wallpapers" "$USER_HOME/.local/share/file-manager" "$USER_HOME/.xinitrc" "$USER_HOME/.fehbg"

# System configs
sudo mkdir -p /etc/lightdm
sudo mkdir -p /etc/X11/xorg.conf.d
sudo mkdir -p /usr/share/xsessions
sudo mkdir -p /usr/share/backgrounds

sudo cp -f "$SCRIPT_DIR/config/lightdm/lightdm.conf" /etc/lightdm/lightdm.conf
sudo cp -f "$SCRIPT_DIR/config/lightdm/lightdm-mini-greeter.conf" /etc/lightdm/lightdm-mini-greeter.conf
sudo cp -f "$SCRIPT_DIR/wallpapers/shishkin.jpg" /usr/share/backgrounds/shishkin.jpg
sudo chmod 644 /usr/share/backgrounds/shishkin.jpg
sudo cp -f "$SCRIPT_DIR/config/lightdm/vxwm.desktop" /usr/share/xsessions/vxwm.desktop
sudo cp -f "$SCRIPT_DIR/config/xorg/00-keyboard.conf" /etc/X11/xorg.conf.d/00-keyboard.conf

# Set lightdm-mini-greeter target user
sudo sed -i "s/^user = .*/user = $TARGET_USER/" /etc/lightdm/lightdm-mini-greeter.conf
sudo sed -i "s/^password-label-text = .*/password-label-text = $TARGET_USER:/" /etc/lightdm/lightdm-mini-greeter.conf

# 7. Enable display manager
echo -e "${GREEN}[7/7] Enabling LightDM display manager...${NC}"
sudo systemctl enable lightdm.service

echo -e "${BLUE}=== Installation Complete! ===${NC}"
echo "You can now reboot your system or run 'startx'."
