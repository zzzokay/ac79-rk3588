#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
fi

DEVICE_IP="${DEVICE_IP:-192.168.1.1}"
UDP_PORT="${UDP_PORT:-2224}"
CTP_PORT="${CTP_PORT:-3333}"
SHOW_WINDOW="${SHOW_WINDOW:-1}"
SAVE_DIR="${SAVE_DIR:-udp_frames}"
SAVE_EVERY="${SAVE_EVERY:-60}"
HEARTBEAT="${HEARTBEAT:-10}"

OPEN_W="${OPEN_W:-640}"
OPEN_H="${OPEN_H:-480}"
OPEN_FPS="${OPEN_FPS:-20}"
OPEN_RATE="${OPEN_RATE:-8000}"
OPEN_FMT="${OPEN_FMT:-0}"

LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
UDP_PID_FILE="$SCRIPT_DIR/udp.pid"

mkdir -p "$LOG_DIR"
mkdir -p "$SAVE_DIR"

PYTHON_BIN="python3"
if [[ -f "$SCRIPT_DIR/.venv/bin/python" ]]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
fi

echo "[INFO] 清理旧进程..."
if [[ -f "$UDP_PID_FILE" ]]; then
    OLD_PID="$(cat "$UDP_PID_FILE" || true)"
    if [[ -n "${OLD_PID:-}" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$UDP_PID_FILE"
fi

pkill -f "jieli_min_udp_client.py" 2>/dev/null || true
pkill -f "jieli_min_ctp_client.py" 2>/dev/null || true

if command -v fuser >/dev/null 2>&1; then
    fuser -k -n udp "$UDP_PORT" 2>/dev/null || true
fi

UDP_ARGS=(--device-ip "$DEVICE_IP" --port "$UDP_PORT")

if [[ -n "${SAVE_DIR:-}" ]]; then
    UDP_ARGS+=(--save-dir "$SAVE_DIR" --save-every "$SAVE_EVERY")
fi

if [[ "$SHOW_WINDOW" == "0" ]]; then
    UDP_ARGS+=(--no-window)
fi


echo "[INFO] 后台启动 UDP 接收器..."
nohup "$PYTHON_BIN" "$SCRIPT_DIR/jieli_min_udp_client.py" \
    "${UDP_ARGS[@]}" \
    > "$LOG_DIR/udp.log" 2>&1 &
UDP_PID=$!
echo "$UDP_PID" > "$UDP_PID_FILE"

sleep 2

if ! kill -0 "$UDP_PID" 2>/dev/null; then
    echo "[ERR] UDP 接收器启动失败，请查看日志：$LOG_DIR/udp.log"
    exit 1
fi

echo "[OK] UDP 已启动，PID=$UDP_PID"
#echo "[INFO] 启动 CTP 并自动发送 app/date/open ..."
echo "[INFO] 后台启动 CTP 并自动发送 app/date/open ..."
(
    {
        sleep 1
        echo "app"
        sleep 1
        echo "date"
        sleep 1
        echo "open $OPEN_W $OPEN_H $OPEN_FPS $OPEN_RATE $OPEN_FMT"
        # 关键：不要让 stdin 结束，保持 CTP 进程活着
        tail -f /dev/null
    } | "$PYTHON_BIN" "$SCRIPT_DIR/jieli_min_ctp_client.py" \
            --mode client \
            --host "$DEVICE_IP" \
            --port "$CTP_PORT" \
            --heartbeat "$HEARTBEAT" \
            --log-file "$LOG_DIR/ctp.log"
) > "$LOG_DIR/ctp_console.log" 2>&1 &
CTP_PID=$!
echo "$CTP_PID" > "$SCRIPT_DIR/ctp.pid"

sleep 2

if ! kill -0 "$CTP_PID" 2>/dev/null; then
    echo "[ERR] CTP 启动失败，请查看日志：$LOG_DIR/ctp_console.log"
    exit 1
fi

echo "[OK] CTP 已启动，PID=$CTP_PID"
echo "[INFO] UDP 正在后台运行，CTP 已保持连接。"
echo "[INFO] 查看 CTP 日志：tail -f $LOG_DIR/ctp_console.log"
echo "[INFO] 查看 UDP 日志：tail -f $LOG_DIR/udp.log"
echo "[INFO] 停止全部：./stop_all.sh"
