#!/bin/bash

THRESHOLD=15

acpi_output=$(acpi -b)
battery_level=$(echo "$acpi_output" | grep -P -o '[0-9]+(?=%)')
charging_state=$(echo "$acpi_output" | grep -o "Charging\|Discharging")

if [[ -z "$battery_level" || -z "$charging_state" ]]; then
    exit 0
fi

if [[ "$battery_level" -le $THRESHOLD && "$charging_state" == "Discharging" ]]; then
    notify-send -u critical "Battery Low" "Battery is at ${battery_level}%!"
fi
