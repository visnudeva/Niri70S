#!/bin/bash

set -e  # Exit on any error
set -u  # Error on unset variables

# --- Trap for cleanup on errors ---
cleanup() {
    echo "[!] Script failed or exited unexpectedly. Performing cleanup."
    # Add cleanup logic here if needed, e.g., removing temp files
}
trap cleanup EXIT

# --- Variables ---
REPO_URL="https://github.com/visnudeva/Niri70S"
CLONE_DIR="${HOME}/Niri70S"
CONFIG_SOURCE="${CLONE_DIR}/.config"
CONFIG_TARGET="${HOME}/.config"
WALLPAPER_NAME="LavaLampOne.png"
WALLPAPER_SOURCE="${CLONE_DIR}/backgrounds/${WALLPAPER_NAME}"
WALLPAPER_DEST="${HOME}/.config/backgrounds/${WALLPAPER_NAME}"
BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

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
AUR_PACKAGES=(ttf-nerd-fonts-symbols)

REQUIRED_CMDS=(git rsync pacman)

# --- Option Defaults ---
FORCE=0
DRYRUN=0
UNATTENDED=0

# --- Functions ---
usage() {
    echo "Usage: $0 [--force] [--dry-run] [--unattended]"
    echo "  --force       Remove existing clone directory without prompt"
    echo "  --dry-run     Only display actions, do not perform them"
    echo "  --unattended  Skip all interactive prompts"
    exit 1
}

log() {
    echo "$@"
}

detect_distro() {
    # Only allow Arch/Manjaro
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro)
                log "[+] Running on supported distro: $ID"
                ;;
            *)
                log "[!] Unsupported distro: $ID. This script only supports Arch Linux and Arch Linux based distros."
                exit 2
                ;;
        esac
    else
        log "[!] Could not detect OS. Aborting."
        exit 2
    fi
}

check_dependencies() {
    local missing=()
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if (( ${#missing[@]} )); then
        log "[!] Missing dependencies: ${missing[*]}"
        exit 3
    fi
}

backup_config() {
    if [[ -d "$CONFIG_TARGET" ]]; then
        log "[+] Backing up existing .config to $BACKUP_DIR"
        if (( DRYRUN )); then
            log "[DRY-RUN] Would backup $CONFIG_TARGET to $BACKUP_DIR"
        else
            cp -r "$CONFIG_TARGET" "$BACKUP_DIR"
        fi
    fi
}

remove_clone_dir() {
    if [[ -d "$CLONE_DIR" ]]; then
        if (( FORCE )) || (( UNATTENDED )); then
            log "[+] Removing existing $CLONE_DIR (--force or --unattended)."
            (( DRYRUN )) || rm -rf "$CLONE_DIR"
        else
            read -p "[?] $CLONE_DIR already exists. Remove and reclone it? [y/N]: " REPLY
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "[+] Removing existing $CLONE_DIR."
                (( DRYRUN )) || rm -rf "$CLONE_DIR"
            else
                log "[!] Aborting due to existing directory."
                exit 4
            fi
        fi
    fi
}

clone_repo() {
    log "[+] Cloning your GitHub repo..."
    if (( DRYRUN )); then
        log "[DRY-RUN] Would run: git clone \"$REPO_URL\" \"$CLONE_DIR\""
    else
        git clone "$REPO_URL" "$CLONE_DIR"
    fi
}

install_packages() {
    log "[+] Installing packages with pacman..."
    if (( DRYRUN )); then
        log "[DRY-RUN] Would run: pacman -S --needed --noconfirm ${PACKAGES[*]}"
    else
        ${SUDO} pacman -S --needed --noconfirm "${PACKAGES[@]}" || log "[!] pacman package installation failed."
    fi
}

install_aur_packages() {
    local aur_helper=""
    for helper in yay paru trizen; do
        if command -v "$helper" &>/dev/null; then
            aur_helper="$helper"
            break
        fi
    done

    if [[ -n "$aur_helper" ]]; then
        log "[+] Installing AUR packages with $aur_helper..."
        if (( DRYRUN )); then
            log "[DRY-RUN] Would run: $aur_helper -S --noconfirm ${AUR_PACKAGES[*]}"
        else
            "$aur_helper" -S --noconfirm "${AUR_PACKAGES[@]}" || log "[!] $aur_helper AUR package installation failed."
        fi
    else
        log "[!] No AUR helper found. Skipping AUR package installation."
    fi
}

copy_dotfiles() {
    log "[+] Copying dotfiles to ~/.config..."
    if (( DRYRUN )); then
        log "[DRY-RUN] Would run: rsync -avh --exclude='.git' \"$CONFIG_SOURCE/\" \"$CONFIG_TARGET/\""
    else
        rsync -avh --exclude='.git' "$CONFIG_SOURCE/" "$CONFIG_TARGET/"
    fi
}

setup_wallpaper() {
    mkdir -p "$HOME/.config/backgrounds"
    if [[ -f "$WALLPAPER_SOURCE" ]]; then
        log "[+] Copying wallpaper to $WALLPAPER_DEST..."
        if (( DRYRUN )); then
            log "[DRY-RUN] Would run: cp \"$WALLPAPER_SOURCE\" \"$WALLPAPER_DEST\""
        else
            cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
            log "[✔] Wallpaper installed."
        fi
    else
        log "[!] Wallpaper not found at $WALLPAPER_SOURCE. Skipping wallpaper setup."
    fi
}

set_login_manager_backgrounds() {
    log "[+] Setting login manager backgrounds..."
    # SDDM
    if command -v sddm &>/dev/null; then
        SDDM_CONF=$(find /usr/share/sddm/themes -name theme.conf 2>/dev/null | head -n 1)
        if [[ -f "$SDDM_CONF" ]]; then
            if (( DRYRUN )); then
                log "[DRY-RUN] Would set SDDM background in $SDDM_CONF"
            else
                ${SUDO} sed -i "s|^Background=.*|Background=$WALLPAPER_DEST|" "$SDDM_CONF" || \
                echo "Background=$WALLPAPER_DEST" | ${SUDO} tee -a "$SDDM_CONF"
                log "[✔] SDDM background set."
            fi
        else
            log "[!] SDDM theme.conf not found."
        fi
    fi

    # LightDM (slick-greeter)
    if [[ -f /etc/lightdm/slick-greeter.conf ]]; then
        if (( DRYRUN )); then
            log "[DRY-RUN] Would set LightDM background in /etc/lightdm/slick-greeter.conf"
        else
            if grep -q "^background=" /etc/lightdm/slick-greeter.conf; then
                ${SUDO} sed -i "s|^background=.*|background=$WALLPAPER_DEST|" /etc/lightdm/slick-greeter.conf
            else
                echo "background=$WALLPAPER_DEST" | ${SUDO} tee -a /etc/lightdm/slick-greeter.conf
            fi
            log "[✔] LightDM background set."
        fi
    fi
}

enable_lingering() {
    if [[ $(id -u) -ne 0 ]]; then
        SUDO="sudo"
    else
        SUDO=""
    fi

    if ${SUDO} loginctl show-user "$USER" --property=Linger &>/dev/null; then
        log "[+] Enabling lingering for $USER..."
        if (( DRYRUN )); then
            log "[DRY-RUN] Would run: ${SUDO} loginctl enable-linger \"$USER\""
        else
            ${SUDO} loginctl enable-linger "$USER"
        fi
    else
        log "[!] loginctl not available or insufficient permissions. Skipping lingering enable."
    fi
}

reload_user_services() {
    log "[+] Reloading user systemd services..."
    if (( DRYRUN )); then
        log "[DRY-RUN] Would run: systemctl --user daemon-reload"
    else
        systemctl --user daemon-reload
    fi
}

check_in_clone_dir() {
    if [[ "$PWD" == "$CLONE_DIR"* ]]; then
        log "[!] You are currently in the directory you're about to delete. Moving to home directory."
        if (( DRYRUN )); then
            log "[DRY-RUN] Would run: cd ~"
        else
            cd ~
        fi
    fi
}

# --- Parse options ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRYRUN=1
            shift
            ;;
        --unattended)
            UNATTENDED=1
            shift
            ;;
        *)
            usage
            ;;
    esac
done

# --- Main Workflow ---
main() {
    detect_distro
    check_dependencies
    enable_lingering
    reload_user_services

    # Remove leftover clone if it's corrupted or broken
    if [[ -d "$CLONE_DIR" && ! -d "$CLONE_DIR/.git" ]]; then
        log "[!] $CLONE_DIR exists but is not a valid git repo. Removing it."
        (( DRYRUN )) || rm -rf "$CLONE_DIR"
    fi

    check_in_clone_dir
    remove_clone_dir
    clone_repo
    install_packages
    install_aur_packages
    backup_config
    copy_dotfiles
    setup_wallpaper
    set_login_manager_backgrounds

    log -e "\n All done! Niri70S setup is complete you now have a fresh Niri installation with its dotfiles and a beautiful wallpaper. Enjoy your new sleek system! \n"
}

main

# --- Remove trap on successful exit ---
trap - EXIT
