#!/bin/bash

set -e  # Exit on error

# --- Configuration ---
REPO_URL="https://github.com/visnudeva/Niri70S"
CLONE_DIR="$HOME/Niri70S"
CONFIG_SOURCE="$CLONE_DIR/.config"
CONFIG_TARGET="$HOME/.config"
WALLPAPER_NAME="LavaLampOne.png"
WALLPAPER_SOURCE="$CLONE_DIR/backgrounds/$WALLPAPER_NAME"
WALLPAPER_DEST="$HOME/.config/backgrounds/$WALLPAPER_NAME"

# Packages to install via pacman
PACKAGES=(
    niri kitty waybar mako swaybg swayidle swaylock-effects swww 
    thunar thunar-volman geany sddm acpi libnotify
    networkmanager network-manager-applet nm-connection-editor
    blueman bluez bluez-utils nwg-look polkit-gnome 
    kvantum kvantum-qt5 qt5-wayland qt6-wayland qt5ct qt6ct
    brightnessctl wl-clipboard grim slurp gvfs 
    xdg-desktop-portal-hyprland yay satty udiskie sddm 
    pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse
    wireplumber pamixer pavucontrol
)

# AUR packages (requires yay)
AUR_PACKAGES=(ttf-nerd-fonts-symbols)

# Enable lingering for persistent user services
loginctl enable-linger "$USER"

# Enable the user service
systemctl --user daemon-reload

# --- Remove leftover clone if it's corrupted or broken ---
if [[ -d "$CLONE_DIR" && ! -d "$CLONE_DIR/.git" ]]; then
    echo "[!] $CLONE_DIR exists but is not a valid git repo. Removing it."
    rm -rf "$CLONE_DIR"
fi

# --- Force remove if user confirms ---
if [[ -d "$CLONE_DIR" ]]; then
    read -p "[?] $CLONE_DIR already exists. Remove and reclone it? [y/N]: " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CLONE_DIR"
        echo "[+] Removed existing $CLONE_DIR."
    fi
fi

# --- Ensure we are not in the deleted directory ---
if [[ "$PWD" == "$CLONE_DIR"* ]]; then
    echo "[!] You are currently in the directory you're about to delete. Moving to home directory."
    cd ~
fi

# --- Clone the repository ---
echo "[+] Cloning your GitHub repo..."
git clone "$REPO_URL" "$CLONE_DIR"

# --- Install necessary packages ---
echo "[+] Installing packages with pacman..."
sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

# --- Install AUR packages if yay is available ---
if command -v yay &>/dev/null; then
    echo "[+] Installing AUR packages with yay..."
    yay -S --noconfirm "${AUR_PACKAGES[@]}"
else
    echo "[!] 'yay' not found. Skipping AUR package installation."
fi

# --- Copy all dotfiles to ~/.config ---
echo "[+] Copying dotfiles to ~/.config..."
rsync -avh --exclude='.git' "$CONFIG_SOURCE/" "$CONFIG_TARGET/"

# --- Copy wallpaper to user config location ---
mkdir -p "$HOME/.config/backgrounds"
if [[ -f "$WALLPAPER_SOURCE" ]]; then
    echo "[+] Copying wallpaper to $WALLPAPER_DEST..."
    cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
    echo "[✔] Wallpaper installed."
else
    echo "[!] Wallpaper not found at $WALLPAPER_SOURCE. Skipping wallpaper setup."
fi

# --- Set background for SDDM and LightDM (slick-greeter) ---
echo "[+] Setting login manager backgrounds..."

# SDDM
if command -v sddm &>/dev/null; then
    SDDM_CONF=$(find /usr/share/sddm/themes -name theme.conf 2>/dev/null | head -n 1)
    if [[ -f "$SDDM_CONF" ]]; then
        sudo sed -i "s|^Background=.*|Background=$WALLPAPER_DEST|" "$SDDM_CONF" || \
        echo "Background=$WALLPAPER_DEST" | sudo tee -a "$SDDM_CONF"
        echo "[✔] SDDM background set."
    else
        echo "[!] SDDM theme.conf not found."
    fi
fi

# LightDM (slick-greeter)
if [[ -f /etc/lightdm/slick-greeter.conf ]]; then
    if grep -q "^background=" /etc/lightdm/slick-greeter.conf; then
        sudo sed -i "s|^background=.*|background=$WALLPAPER_DEST|" /etc/lightdm/slick-greeter.conf
    else
        echo "background=$WALLPAPER_DEST" | sudo tee -a /etc/lightdm/slick-greeter.conf
    fi
    echo "[✔] LightDM background set."
fi

# --- Final message ---
echo -e "\n All done! Niri70S setup is complete with fresh dotfiles and a beautiful wallpaper. Enjoy your sleek system! \n"
