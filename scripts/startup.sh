#!/bin/bash
set -e
set -x

# 强制使用 headless 用户的主目录
HOME_DIR="/home/headless"
USERNAME="headless"
USERID=1001

echo "当前用户: $USERNAME (UID: $USERID)"
echo "准备X11环境..."

# 确保主目录存在
mkdir -p "$HOME_DIR"

# 清理旧的 X11 锁文件
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# 在正确的目录创建 Xauthority
touch "$HOME_DIR/.Xauthority"
chmod 600 "$HOME_DIR/.Xauthority"

# 生成 X11 认证
if [ -z "$(xauth list :1 2>/dev/null)" ]; then
    xauth generate :1 . trusted
    xauth add :1 . $(mcookie)
fi

# 设置 VNC 密码
if [ ! -f "$HOME_DIR/.vnc/passwd" ]; then
    mkdir -p "$HOME_DIR/.vnc"
    echo "${VNC_PW:-vncpassword}" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
    chmod 600 "$HOME_DIR/.vnc/passwd"
fi

export DISPLAY=:1
export XAUTHORITY="$HOME_DIR/.Xauthority"

echo "启动 VNC 服务..."
/usr/bin/Xvnc :1 -desktop Ubuntu -geometry 1360x768 -depth 24 \
    -rfbport 5901 \
    -rfbauth "$HOME_DIR/.vnc/passwd" \
    -auth "$HOME_DIR/.Xauthority" \
    -SecurityTypes VncAuth -AlwaysShared -AcceptKeyEvents -AcceptPointerEvents -AcceptCutText -SendCutText -localhost no > /tmp/vnc.log 2>&1 &
VNCPID=$!
echo "VNC PID: $VNCPID"
sleep 5

if ! ps -p $VNCPID > /dev/null; then
    echo "VNC 启动失败"
    cat /tmp/vnc.log
    exit 1
fi

echo "启动 Xfce..."
DISPLAY=:1 startxfce4 > /tmp/xfce.log 2>&1 &
XFCEPID=$!
echo "Xfce PID: $XFCEPID"
sleep 10

if ! ps -p $XFCEPID > /dev/null; then
    echo "Xfce 启动失败"
    cat /tmp/xfce.log
fi

echo "检查 X..."
DISPLAY=:1 xdpyinfo > /dev/null 2>&1

echo "启动 noVNC..."
/usr/bin/websockify --web=/usr/share/novnc 6901 localhost:5901 > /tmp/novnc.log 2>&1 &
NOVNCPID=$!
echo "noVNC PID: $NOVNCPID"
sleep 3

echo "启动 Flask Web 服务..."
cd /app/web-app
python3 app.py > /tmp/flask.log 2>&1 &
FLASKPID=$!
echo "Flask PID: $FLASKPID"
echo
echo "全部服务已启动。"

# 守护进程,监控服务
while true; do
    sleep 60
    if ! ps -p $VNCPID > /dev/null; then
        echo "VNC进程异常退出"
        exit 1
    fi
    if ! ps -p $FLASKPID > /dev/null; then
        echo "Flask进程异常退出,重启..."
        cd /app/web-app
        python3 app.py > /tmp/flask.log 2>&1 &
        FLASKPID=$!
    fi
done
