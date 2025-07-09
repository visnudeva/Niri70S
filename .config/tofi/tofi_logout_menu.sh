#!/bin/bash

# Define your logout options with icons (optional, if using a patched Nerd Font)
actions=(
  "󰍁  Lock"
  "󰍃  Logout"
  "󰜉  Reboot"
  "  Shutdown"
  "󰤄  Suspend"
)

# Join options with newline
choices=$(printf "%s\n" "${actions[@]}")

# Use tofi with explicit config path to apply theme
selection=$(echo "$choices" | tofi --config ~/.config/tofi/configA)

# Extract action name by removing icon (everything after two spaces)
action_name=$(echo "$selection" | cut -d' ' -f3-)

# Run the selected action
case "$action_name" in
  "Lock")
    swaylock || hyprlock || echo "No lock utility found"
    ;;
  "Logout")
    hyprctl dispatch exit
    ;;
  "Reboot")
    systemctl reboot
    ;;
  "Shutdown")
    systemctl poweroff
    ;;
  "Suspend")
    systemctl suspend
    ;;
  *)
    # Do nothing if no valid selection
    ;;
esac
