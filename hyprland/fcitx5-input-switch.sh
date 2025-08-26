#!/usr/bin/env bash
# Place this file in ~/.local/lib/hyde

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
source "$scrDir/globalcontrol.sh"

CAPS_SYMBOL="%{F#c0392b}⇧%{F-}"
IMLIST_FILE="/tmp/fcitx5-imlist"

capslock() {
  xset -q | grep Caps | grep -q on && {
    echo on
    return 0
  } || {
    echo off
    return 1
  }
}

# Print out identifier of current input method
current() {
  dbus-send --session --print-reply \
    --dest=org.fcitx.Fcitx5 \
    /controller \
    org.fcitx.Fcitx.Controller1.CurrentInputMethod \
    | grep -Po '(?<=")[^"]+'
}

# List all input methods added to Fcitx
imlist() {
  if [ ! -f "${IMLIST_FILE}" ]; then
    dbus-send --session --print-reply \
      --dest=org.fcitx.Fcitx5 \
      /controller \
      org.fcitx.Fcitx.Controller1.AvailableInputMethods \
      | awk 'BEGIN{i=0}{
          if($0~/struct {/) {
              i=0;
          }
          else if($0~/string "/) {
              if(match($0, /"([^"]*)"/)) {
                  field = substr($0, RSTART+1, RLENGTH-2)
                  if(i<5) {
                      printf("%s|", field)
                  } else if(i==5) {
                      printf("%s|", field)
                  }
                  i++
              }
          }
          else if($0~/boolean/) {
              if($0~/true/) {
                  printf("true\n")
              } else {
                  printf("false\n")
              }
              i++
          }
      }' > ${IMLIST_FILE}
  fi

  cat ${IMLIST_FILE}
}

print_pretty_name() {
  name=$(imlist | grep "^$(current)|" | cut -d'|' -f2)
  if [[ -z "$name" ]]; then
    return
  fi
  echo "${name}"
}

fcitx5-remote -t

layMain=$(print_pretty_name)

# This was used in a HyDE setup, you can change the icon path to your own
notify-send -a "HyDE Alert" -r 91190 -t 800 -i "${ICONS_DIR}/Wallbash-Icon/keyboard.svg" "${layMain}"
