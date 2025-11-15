#!/bin/bash
set -e
set -x

USERNAME=$(whoami)
USERID=$(id -u)

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true
touch /home/$USERNAME/.Xauthority
chmod 600 /home/$USERNAME/.Xauthority

if [ -z "$(xauth list :1 2>/dev/null)" ]; then
  xauth generate :1 . trusted || xauth add :1 . $(mcookie)
fi

if [ ! -f /home/$USERNAME/.vncpasswd ]; then
  echo "创建vnc密码文件..."
  echo "${VNC_PW:-vncpassword}" | vncpasswd -f > /home/$USERNAME/.vncpasswd
  chmod 600 /home/$USERNAME/.vncpasswd
fi

export DISPLAY=:1
export XAUTHORITY=/home/$USERNAME/.Xauthority

/usr/bin/Xvnc :1 -desktop "Ubuntu自动化平台" -geometry 1360x768 -depth 24 \
    -rfbport 5901 -rfbauth /home/$USERNAME/.vncpasswd -auth $XAUTHORITY \
    -SecurityTypes VncAuth -AlwaysShared -AcceptKeyEvents -AcceptPointerEvents \
    -AcceptCutText -SendCutText -localhost no > /tmp/vnc.log 2>&1 &

sleep 5

DISPLAY=:1 startxfce4 > /tmp/xfce.log 2>&1 &

sleep 10

# noVNC 监听 5901 显示VNC, 但不暴露外网端口，只能通过5000端口代理访问
/usr/bin/websockify --web=/usr/share/novnc 6901 localhost:5901 > /tmp/novnc.log 2>&1 &

cd /app/web-app
python3 /app/web-app/app.py > /tmp/flask.log 2>&1 &

while true; do
  sleep 60
done
