#!/bin/bash
set -e
set -x

USERNAME=$(whoami)
USERID=$(id -u)
echo "当前用户: $USERNAME (UID: $USERID)"

echo "准备X11环境..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

if [ ! -d "/home/$USERNAME" ]; then
  mkdir -p "/home/$USERNAME"
  chown $USERID:$USERID "/home/$USERNAME"
fi
touch "/home/$USERNAME/.Xauthority"
chmod 600 "/home/$USERNAME/.Xauthority"

export DISPLAY=:1
export XAUTHORITY="/home/$USERNAME/.Xauthority"

echo "DISPLAY设置为: $DISPLAY"
echo "XAUTHORITY设置为: $XAUTHORITY"

# ===================================================================
# VNC 密码配置
# ===================================================================
if [ ! -f "/home/$USERNAME/.vncpasswd" ]; then
  echo "创建VNC密码文件..."
  echo "${VNC_PW:-vncpassword}" | vncpasswd -f > "/home/$USERNAME/.vncpasswd"
  chmod 600 "/home/$USERNAME/.vncpasswd"
fi

# ===================================================================
# Cloudflare Tunnel 配置(可选)
# ===================================================================
if [ "$ENABLE_CLOUDFLARE_TUNNEL" = "true" ]; then
    echo "启动 Cloudflare Tunnel..."
    if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" > /tmp/cloudflared.log 2>&1 &
        CF_PID=$!
        echo "Cloudflare Tunnel PID: $CF_PID"
    else
        echo "缺少 Cloudflare 隧道令牌,隧道未启动"
    fi
else
    echo "未启用 Cloudflare Tunnel"
fi

# ===================================================================
# 关键修复: 确保 VNC xstartup 脚本存在并配置正确
# ===================================================================
if [ ! -f "/home/$USERNAME/.vnc/xstartup" ]; then
    echo "创建 VNC xstartup 脚本..."
    mkdir -p "/home/$USERNAME/.vnc"
    cat << 'EOF' > "/home/$USERNAME/.vnc/xstartup"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

[ -r /etc/X11/Xresources ] && xrdb /etc/X11/Xresources
[ -r "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

xsetroot -solid grey &
xset s off &
xset -dpms &
xset s noblank &

export GTK_IM_MODULE=xim
export QT_IM_MODULE=xim
export XMODIFIERS=@im=none
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

exec /usr/bin/startxfce4
EOF
    chmod +x "/home/$USERNAME/.vnc/xstartup"
fi

# ===================================================================
# 启动 VNC 服务器
# ===================================================================
echo "启动VNC服务器..."
/usr/bin/Xvnc :1 -desktop "Ubuntu自动化平台" -geometry 1360x768 -depth 24 \
    -rfbport 5901 -rfbauth "/home/$USERNAME/.vncpasswd" -auth "$XAUTHORITY" \
    -SecurityTypes VncAuth -AlwaysShared -AcceptKeyEvents -AcceptPointerEvents \
    -AcceptCutText -SendCutText -localhost no > /tmp/vnc.log 2>&1 &

VNC_PID=$!
sleep 5

if ! ps -p $VNC_PID > /dev/null; then
  echo "错误: VNC服务器启动失败"
  cat /tmp/vnc.log
  exit 1
fi

# ===================================================================
# 生成 X authority
# ===================================================================
if [ -z "$(xauth list :1 2>/dev/null)" ]; then
  xauth generate :1 . trusted || xauth add :1 . $(mcookie)
fi

# ===================================================================
# 启动 XFCE 桌面环境
# ===================================================================
echo "启动Xfce桌面环境..."
DISPLAY=:1 startxfce4 > /tmp/xfce.log 2>&1 &
XFCE_PID=$!
sleep 10

if ! ps -p $XFCE_PID > /dev/null; then
  echo "警告: Xfce进程可能已退出,检查日志..."
  cat /tmp/xfce.log
fi

# ===================================================================
# 验证 X 服务器连接
# ===================================================================
echo "验证X服务器连接..."
DISPLAY=:1 xdpyinfo > /dev/null 2>&1 && echo "X服务器连接正常" || echo "警告: X服务器连接异常"

# ===================================================================
# 启动 noVNC 服务
# ===================================================================
echo "启动noVNC服务..."
/usr/bin/websockify --web=/usr/share/novnc 6901 localhost:5901 > /tmp/novnc.log 2>&1 &
NOVNC_PID=$!
sleep 3

# ===================================================================
# 启动 Flask Web 管理平台
# ===================================================================
echo "启动Flask Web管理平台..."
cd /app/web-app
python3 app.py > /tmp/flask.log 2>&1 &
FLASK_PID=$!

echo "==========================================="
echo "所有服务启动完成!"
echo "VNC PID: $VNC_PID"
echo "XFCE PID: $XFCE_PID"
echo "noVNC PID: $NOVNC_PID"
echo "Flask PID: $FLASK_PID"
echo "==========================================="

# ===================================================================
# 服务监控循环
# ===================================================================
while true; do
  sleep 60
  if ! ps -p $VNC_PID > /dev/null; then
    echo "错误: VNC服务器已停止"
    exit 1
  fi
  if ! ps -p $FLASK_PID > /dev/null; then
    echo "Flask服务已停止,尝试重启..."
    cd /app/web-app
    python3 app.py > /tmp/flask.log 2>&1 &
    FLASK_PID=$!
  fi
done
