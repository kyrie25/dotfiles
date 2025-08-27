#!/usr/bin/env bash

# Place this file in ~/.config/hypr/scripts/
# Adapted from HyDE's brightnesscontrol.sh
# This script adjusts brightness for both laptop and external monitors using brightnessctl and ddcutil.
# It changes brightness of the active monitor only.
# The only reason you need this is when ddcci-driver-linux-dkms does not work, else don't bother.

scrDir=$HOME/.local/lib/hyde
# shellcheck disable=SC1091
source "$scrDir/globalcontrol.sh"

DDCUTIL_FILE="/tmp/ddcutil-list"

activeMonitor=$(hyprctl activeworkspace -j | jq -r '.monitor')

# If you have to frequently change monitors, use the next line for conditional update so it updates when new monitor is active
# if [[ ! -f $DDCUTIL_FILE ]] || ! grep -q "|$activeMonitor|" "$DDCUTIL_FILE"; then

if [[ ! -f $DDCUTIL_FILE ]]; then
    ddcutil detect --skip-ddc-checks | awk '
    /I2C bus:/ {
        bus = $3
        gsub(/\/dev\/i2c-/, "", bus)
    }
    /DRM_connector:/ {
        connector = $2
        gsub(/card[0-9]+-/, "", connector)
    }
    /Model:/ && NF > 1 {
        model = $2
        for(i=3; i<=NF; i++) model = model " " $i
        gsub(/^[ \t]+|[ \t]+$/, "", model)
        if(model != "") print bus "|" connector "|" model
    }' > "$DDCUTIL_FILE"
fi
monitorInfo=$(cat "$DDCUTIL_FILE")
busNumber=$(echo "$monitorInfo" | awk -F'|' -v monitor="$activeMonitor" '$2 == monitor {print $1}')

# Check if SwayOSD is installed
use_swayosd=false
isNotify=${BRIGHTNESS_NOTIFY:-true}
if command -v swayosd-client >/dev/null 2>&1 && pgrep -x swayosd-server >/dev/null; then
    use_swayosd=true
fi

send_notification() {
    # If bus number not empty
    if [ -n "$busNumber" ]; then
        brightinfo=$(echo "$monitorInfo" | awk -F'|' -v monitor="$activeMonitor" '$2 == monitor {print $3}')
    else
        brightinfo=$(brightnessctl info | awk -F "'" '/Device/ {print $2}')
    fi

    brightness=$(get_brightness)
    angle=$((((brightness + 2) / 5) * 5))
    # shellcheck disable=SC2154
    ico="${iconsDir}/Wallbash-Icon/media/knob-${angle}.svg"
    bar=$(seq -s "." $((brightness / 15)) | sed 's/[0-9]//g')
    [[ "${isNotify}" == true ]] && notify-send -a "HyDE Notify" -r 7 -t 800 -i "${ico}" "${brightness}${bar}" "${brightinfo}"
}

get_brightness() {
    if [ -n "$busNumber" ]; then
        ddcutil getvcp 10 --bus="$busNumber" --skip-ddc-checks --noverify | grep "current value" | cut -d'=' -f2 | cut -d',' -f1 | tr -d ' '
        return
    else
        brightnessctl -m | grep -o '[0-9]\+%' | head -c-2
        return
    fi
}

increase_brightness() {
    if [ -n "$busNumber" ]; then
        ddcutil setvcp 10 + "$1" --bus="$busNumber" --skip-ddc-checks --noverify
    else
        brightnessctl set +"$1"%
    fi
}

decrease_brightness() {
    if [ -n "$busNumber" ]; then
        ddcutil setvcp 10 - "$1" --bus="$busNumber" --skip-ddc-checks --noverify
    else
        brightnessctl set "$1"%-
    fi
}

step=${BRIGHTNESS_STEPS:-5}
step="${2:-$step}"
brightness=$(get_brightness)

case $1 in
    i) # increase the backlight
        if [[ $brightness -lt 10 ]]; then
            # increase the backlight by 1% if less than 10%
            step=1
        fi

        $use_swayosd && swayosd-client --brightness raise "$step" && exit 0
        increase_brightness "$step"
        send_notification
        ;;

    d) # decrease the backlight
        if [[ $brightness -le 10 ]]; then
            # decrease the backlight by 1% if less than 10%
            step=1
        fi

        if [[ $brightness -le 1 ]]; then
            decrease_brightness 1
            $use_swayosd && exit 0
        else
            $use_swayosd && swayosd-client --brightness lower "$step" && exit 0
            decrease_brightness "$step"
        fi
        send_notification
        ;;
    *)
        ;;
esac