#!/usr/bin/env bash

# Place this file in ~/.config/hypr/scripts/
# Adapted from HyDE's brightnesscontrol.sh
# This script adjusts brightness for both laptop and external monitors using brightnessctl.
# It changes brightness of all monitors simultaneously. Only works if you have brightnessctl-git installed.

scrDir=~/.local/lib/hyde
# shellcheck disable=SC1091
source "$scrDir/globalcontrol.sh"

# Check if SwayOSD is installed
use_swayosd=false
isNotify=${BRIGHTNESS_NOTIFY:-true}
if command -v swayosd-client >/dev/null 2>&1 && pgrep -x swayosd-server >/dev/null; then
    use_swayosd=true
fi

send_notification() {
    brightness=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)" | cat)
    brightinfo=$(brightnessctl info --class="backlight" | awk -F "'" '/Device/ {print $2}')
    angle="$((((brightness + 2) / 5) * 5))"
    # shellcheck disable=SC2154
    ico="${iconsDir}/Wallbash-Icon/media/knob-${angle}.svg"
    bar=$(seq -s "." $((brightness / 15)) | sed 's/[0-9]//g')
    [[ "${isNotify}" == true ]] && notify-send -a "HyDE Notify" -r 7 -t 800 -i "${ico}" "${brightness}${bar}" "${brightinfo}"
}

get_brightness() {
    brightnessctl -m | grep -o '[0-9]\+%' | head -c-2
}

step=${BRIGHTNESS_STEPS:-5}
step="${2:-$step}"

case $1 in
i | -i) # increase the backlight
    if [[ $(get_brightness) -lt 10 ]]; then
        # increase the backlight by 1% if less than 10%
        step=1
    fi

    $use_swayosd && swayosd-client --brightness raise "$step" && exit 0
    brightnessctl set +"${step}"% --class="backlight"
    send_notification
    ;;
d | -d) # decrease the backlight

    if [[ $(get_brightness) -le 10 ]]; then
        # decrease the backlight by 1% if less than 10%
        step=1
    fi

    if [[ $(get_brightness) -le 1 ]]; then
        brightnessctl set "${step}"% --class="backlight"
        $use_swayosd && exit 0
    else
        $use_swayosd && swayosd-client --brightness lower "$step" && exit 0
        brightnessctl set "${step}"%- --class="backlight"
    fi

    send_notification
    ;;
*)
    ;;
esac
