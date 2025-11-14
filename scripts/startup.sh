#!/bin/bash
set -x

USERNAME=$(whoami)
USERID=$(id -u)

# 清理并重建X11 socket目录
rm -rf /tmp/.X11-unix
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# 确保 .Xauthority 和 .vncpasswd 归属当前用户
touch /home/$USERNAME/.Xauthority
chmod 600 /home/$USERNAME/.Xauthority
chown $USERID /home/$USERNAME/.Xauthority

if [ ! -f "/home/$USERNAME/.vncpasswd" ]; then
  echo "vncpassword" | vncpasswd -f > "/home/$USERNAME/.vncpasswd"
  chmod 600 "/home/$USERNAME/.vncpasswd"
  chown $USERID "/home/$USERNAME/.vncpasswd"
fi

export DISPLAY=:1
export XAUTHORITY="/home/$USERNAME/.Xauthority"

/usr/bin/Xvnc :1 \
    -depth 24 \
    -geometry 1360x768 \
    -rfbport 5901 \
    -auth $XAUTHORITY \
    -rfbauth /home/$USERNAME/.vncpasswd \
    -desktop vncdesktop \
    -pn &

sleep 4

DISPLAY=:1 startxfce4 &

sleep 8

nohup python3 /app/web-app/app.py &

tail -f /dev/null
