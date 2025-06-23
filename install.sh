#!/bin/bash

set -e  # Exit on error

# --- Configuration ---
REPO_URL="https://github.com/visnudeva/HyprNiri"
CLONE_DIR="$HOME/HyprNiri"
CONFIG_SOURCE="$CLONE_DIR/.config"
CONFIG_TARGET="$HOME/.config"
WALLPAPER_NAME="LavaLampOne.png"
WALLPAPER_SOURCE="$CONFIG_SOURCE/hypr/$WALLPAPER_NAME"
WALLPAPER_DEST="/usr/share/backgrounds/$WALLPAPER_NAME"
TMP_DIR=$(mktemp -d)

# Packages to install via pacman
PACKAGES=(
    hyprland niri kitty waybar dunst swaybg hyprlock hypridle thunar 
    thunar-volman gvfs geany blueman nwg-look polkit-gnome 
    pavucontrol brightnessctl wl-clipboard grim slurp qt5-wayland
    qt6-wayland xdg-desktop-portal-hyprland
)

# AUR packages (requires yay)
AUR_PACKAGES=(tofi ttf-nerd-fonts-symbols)

# --- Clone the repository ---
if [[ -d "$CLONE_DIR" && -n "$(ls -A "$CLONE_DIR")" ]]; then
    echo "[!] Directory $CLONE_DIR already exists and is not empty. Skipping clone."
else
    echo "[+] Cloning your GitHub repo..."
    git clone "$REPO_URL" "$CLONE_DIR"
fi

# --- Install necessary packages ---
echo "[+] Installing packages with pacman..."
sudo pacman -Syu --noconfirm "${PACKAGES[@]}"

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

# --- Copy wallpaper to system-wide location ---
if [[ -f "$WALLPAPER_SOURCE" ]]; then
    echo "[+] Copying wallpaper to $WALLPAPER_DEST..."
    sudo cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
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

# --- Install Catppuccin Mocha GTK and icon theme ---
echo "[+] Installing Catppuccin Mocha GTK and icon themes..."

# Clone themes
git clone --depth=1 https://github.com/catppuccin/gtk.git "$TMP_DIR/gtk"
git clone --depth=1 https://github.com/catppuccin/icons.git "$TMP_DIR/icons"

# Install to user theme/icon directories
mkdir -p "$HOME/.themes" "$HOME/.icons"
cp -r "$TMP_DIR/gtk/src/mocha" "$HOME/.themes/"
cp -r "$TMP_DIR/icons/Catppuccin-Mocha" "$HOME/.icons/"

# Set dark theme using gsettings
echo "[+] Applying Catppuccin Mocha themes..."
gsettings set org.gnome.desktop.interface gtk-theme "mocha"
gsettings set org.gnome.desktop.interface icon-theme "Catppuccin-Mocha"
gsettings set org.gnome.desktop.wm.preferences theme "mocha"

# --- Final message ---
echo -e "\n All done! Hyprland + Niri setup is complete with fresh dotfiles, a beautiful wallpaper, and Catppuccin Mocha vibes. Enjoy your sleek system! \n"
