#!/bin/bash
set -uo pipefail
XDG_RUNTIME_DIR="/run/user/$UID"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}"
cd "$SCRIPT_DIR" || exit 1
source "$SCRIPT_DIR/config.sh"

# ===================== 配置区 =====================
TARGET_WS="special:kitbar"
ALLOW_CLASS="kitbar"
HYPR_SOCKET="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
# ==================================================

cleanup() {
    tput cnorm
    stty echo
    clear
}
trap '' SIGINT SIGQUIT SIGTSTP SIGTERM
trap cleanup EXIT

print_static_status() {
    clear
    tput cup 0 0
    echo -e "$title"
    tput civis
    stty -echo -icanon -isig
}

print_static_status

get_kitbar_addr() {
    hyprctl clients 2>/dev/null | while read -r line; do
        case "$line" in
        Window*)
            addr="${line#Window }"
            addr="${addr%% *}"
        ;;
        *"class: $ALLOW_CLASS"*)
            echo "$addr"
            return
        ;;
        esac
    done
}

get_current_ws() {
    line=$(hyprctl activeworkspace 2>/dev/null | head -n1)
    parts=($line)
    echo "${parts[2]}"
}

hyprctlmove(){
    local ws="$1"
    local address="$2"
    hyprctl dispatch movetoworkspacesilent "$ws,address:0x$address" &>/dev/null #添加16进制开头0x
}

# 初始化
has_kitbar=false
kitbar_addr=$(get_kitbar_addr)
if [ -n "$kitbar_addr" ]; then
    hyprctlmove "$TARGET_WS" "$kitbar_addr"
    has_kitbar=true
fi

# 事件监听
while read -r event; do
    case "$event" in
        movewindowv2*)
            IFS=',' read -r win_id _ to <<< "${event#*>>}"
            if [[ " $kitbar_addr " == " $win_id " ]]; then
                if [[ "$to" != "$TARGET_WS" ]]; then
                    hyprctlmove "$TARGET_WS" "$win_id"
                fi
            else
                if [[ "$to" == "$TARGET_WS" ]]; then
                    hyprctlmove "$(get_current_ws)" "$win_id"
                fi
            fi
            ;;
        openwindow*)
            IFS=',' read -r win_id ws win_class _ <<< "${event#*>>}"
            if [[ $ws == "$TARGET_WS" && $win_class != "$ALLOW_CLASS" ]]; then
                hyprctlmove "$(get_current_ws)" "$win_id"
            fi
            if [[ $win_class == "$ALLOW_CLASS" && $has_kitbar == false ]];then
                kitbar_addr="$win_id"
            fi
            ;;
        closewindow*)
            if [[ $kitbar_addr == "$win_id" ]]; then
                has_kitbar=false
            fi
            ;;
    esac
done < <(socat UNIX-CONNECT:"$HYPR_SOCKET" - 2>/dev/null)