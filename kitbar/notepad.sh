#!/bin/bash

# 自动配置 notepad 命令
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NOTE_FILE="$SCRIPT_DIR/notepad"

stty -echo -icanon

trap '' SIGINT SIGQUIT SIGTSTP SIGTERM
trap 'rm -f "$TEMP_CMD"; tput cnorm; clear; exit' EXIT

touch "$NOTE_FILE"
tput civis
clear

tput home
cat "$NOTE_FILE"

# 事件监听：文件被修改才刷新
while true; do
  inotifywait -qq -e modify "$NOTE_FILE"
  clear
  tput home
  cat "$NOTE_FILE"
done