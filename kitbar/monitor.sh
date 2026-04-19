#!/bin/bash
# ========== 配置 ==========
PANEL_ROWS=4
GAP=1
# ========== 信号处理 ==========
trap '' INT TERM
trap 'tput cnorm; tput cup $PANEL_ROWS 0; tput ed; exit 0' EXIT
tput civis

# 全局缓存
OLD_COLS=0
LAST_SEC=""
# 状态缓存
CACHE_WS="?"
CACHE_VOL=""
CACHE_BRIGHT=""
CACHE_WIFI=""
CACHE_BT=""

# ========== 精准获取下一秒休眠时间 ==========
sleep_to_next_second() {
    local now=$(date +%N)
    local ms=$((1000 - 10#$now / 1000000))
    sleep "0.${ms: -3}"
}

# ========== 主循环 ==========
while true; do
    TERM_COLS=$(tput cols)
    PANEL_COLS=$((TERM_COLS - GAP))
    CONTENT_WIDTH=$((PANEL_COLS - 2))

    # 仅终端宽度变化时清屏
    if [ $TERM_COLS -ne $OLD_COLS ]; then
        tput clear
        OLD_COLS=$TERM_COLS
    fi

    BORDER=$(printf "%0.s─" $(seq 1 $CONTENT_WIDTH))

    # ==================== 布局计算 ====================
    FIXED_CHARS=19
    REMAIN=$(( CONTENT_WIDTH - FIXED_CHARS ))
    RIGHT=$(( REMAIN / 2 ))
    PAD=$(( REMAIN % 2 ))
    
    # ==================== 仅秒数更新时获取时间 ====================
    CURRENT_SEC=$(date +%S)
    TIME_STR=$(date "+%Y-%m-%d %H:%M:%S")
    FIXED_LINE2=17
    SPACE_LINE1=$(( CONTENT_WIDTH - FIXED_LINE2 - ${#TIME_STR} - 3 ))
    [ $SPACE_LINE1 -lt 0 ] && SPACE_LINE1=0

    # ==================== 系统状态获取 ====================
    # 每2秒更新一次硬件状态
    if [ $((10#$CURRENT_SEC % 2)) -eq 0 ] || [ "$LAST_SEC" = "" ]; then
        # 1. 工作区
        WS=$(hyprctl activeworkspace -j | jq -r '.id' 2>/dev/null || echo "?")
        # 2. 音量/亮度
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%d%%",$2*100}')
        BRIGHT=$(brightnessctl i 2>/dev/null | grep -o '[0-9]\+%' | head -1)
        # 3. wifi
        WIFI=$(nmcli connection show --active 2>/dev/null | awk '/wifi/ {print $1; exit}' || echo "none")
        # 4. 蓝牙
        BT=$(bluetoothctl devices 2>/dev/null | awk 'NR==1{$1=$2="";sub(/^ /,"");print}')
        [ -z "$BT" ] && BT="none"
        # 更新缓存
        CACHE_WS=$WS
        CACHE_VOL=$VOL
        CACHE_BRIGHT=$BRIGHT
        CACHE_WIFI=$WIFI
        CACHE_BT=$BT
    fi

    # ==================== 仅秒数变化时刷新界面 ====================
    if [ "$CURRENT_SEC" != "$LAST_SEC" ]; then
        tput cup 0 0
        echo "╭${BORDER}╮"
        printf "│ 󰕾 %3.3s 󰃠 %3.3s 󰂯 %-${RIGHT}.${RIGHT}s 󰖩 %-${RIGHT}.${RIGHT}s%${PAD}s │\n" \
               "$CACHE_VOL" "$CACHE_BRIGHT" "$CACHE_BT" "$CACHE_WIFI" ""
        printf "│ 󰙅 workspace:%-3.3s%${SPACE_LINE1}s 󰃰 %19.19s │\n" "$CACHE_WS" "" "$TIME_STR"
        echo "╰${BORDER}╯"
        tput cup $PANEL_ROWS 0
        LAST_SEC=$CURRENT_SEC
    fi

    # 休眠到下一秒
    sleep_to_next_second
done