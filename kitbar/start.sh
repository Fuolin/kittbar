#!/bin/bash
set -uo pipefail
# ===================== 全局单实例锁 =====================
LOCK_FILE="/tmp/kitbar.lock"
# 检查锁文件
if [ -f "$LOCK_FILE" ]; then
  OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  # 进程仍在运行，直接退出
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  # 进程已死，清理残留锁
  else
    rm -f "$LOCK_FILE"
  fi
fi
# 创建锁并写入当前PID
touch "$LOCK_FILE"
echo "$$" > "$LOCK_FILE"

#config文件
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/config.sh"

cd "$SCRIPT_DIR" || exit 1
#脚本的所有文件都在当前目录

LOCAL_SOCKET=""
KITTY_PID=""

# 退出时自动清理锁
cleanup() {
  pkill -P $$ 2>/dev/null
  rm -f "$LOCK_FILE"
  # 仅当PID存在时才kill
  [ -n "$KITTY_PID" ] && kill "$KITTY_PID" 2>/dev/null
  rm -f /tmp/kitbar-* /tmp/socket-*.tmp 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ====================== 启动终端 ======================
kitbar::launch() {
   # 清空残留Socket
    rm -f /tmp/kitbar-* /tmp/socket-*.tmp 2>/dev/null

    TMP_SOCKET_FILE="/tmp/socket-$$.tmp"

    kitty --class kitbar --config "$SCRIPT_DIR/kitbar.conf"\
    bash -c "echo \$KITTY_LISTEN_ON > '$TMP_SOCKET_FILE'; exec bash" 2>/dev/null &

    # 保存 Kitty 进程 PID
    KITTY_PID=$!
    sleep 0.3  # 短暂等待终端启动

    if [ ! -f "$TMP_SOCKET_FILE" ]; then
        LOCAL_SOCKET=""
        return
    fi

    # 读取 Socket 地址
    LOCAL_SOCKET=$(cat "$TMP_SOCKET_FILE" 2>/dev/null)
    rm -f "$TMP_SOCKET_FILE"
  
    kitten @ --to "$LOCAL_SOCKET" launch --location=hsplit --bias=$bottom --match id:1 >/dev/null 2>&1
    sleep 0.1

    kitten @ --to "$LOCAL_SOCKET" send-text --match id:1 " ./monitor.sh\n"

    kitten @ --to "$LOCAL_SOCKET" launch --location=vsplit --bias=40 --match id:2 >/dev/null 2>&1
    sleep 0.1
    kitten @ --to "$LOCAL_SOCKET" launch --location=vsplit --bias=1 --match id:3 >/dev/null 2>&1
    sleep 0.1

    kitten @ --to "$LOCAL_SOCKET" send-text --match id:4 " ./notepad.sh\n"
    kitten @ --to "$LOCAL_SOCKET" send-text --match id:3 " shopt -s expand_aliases\n alias notepad='nano $SCRIPT_DIR/notepad'\n cd\n clear\n"
    kitten @ --to "$LOCAL_SOCKET" send-text --match id:2 " ./guard.sh\n"
}

# ====================== 主循环 ======================
main() {
  while true; do
    if [ -z "${LOCAL_SOCKET}" ] || ! kill -0 "${KITTY_PID}" 2>/dev/null; then
      kitbar::launch
      sleep 0.5
      continue
    fi

    sleep $REFRESH
  done
}

main