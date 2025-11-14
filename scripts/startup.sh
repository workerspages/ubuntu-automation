#!/bin/bash

# 清理可能的X11残留
rm -rf /tmp/.X11-unix

# 创建VNC密码文件
VNC_PASSWD_FILE="/home/headless/.vncpasswd"
if [ ! -f "$VNC_PASSWD_FILE" ]; then
  mkdir -p /home/headless
  echo "vncpassword" | vncpasswd -f > "$VNC_PASSWD_FILE"
  chmod 600 "$VNC_PASSWD_FILE"
fi

# 创建Xauthority文件
if [ ! -f "/home/headless/.Xauthority" ]; then
  touch /home/headless/.Xauthority
  chmod 600 /home/headless/.Xauthority
fi

# 设置X认证环境变量
export DISPLAY=:1
export XAUTHORITY=/home/headless/.Xauthority

# 启动VNC服务器
/usr/bin/Xvnc :1 \
    -depth 24 \
    -geometry 1360x768 \
    -rfbport 5901 \
    -auth /home/headless/.Xauthority \
    -rfbauth /home/headless/.vncpasswd \
    -desktop vncdesktop \
    -pn &

# 等待VNC服务启动完成
sleep 4

# 启动Xfce桌面环境
startxfce4 &

# 等待桌面完全准备好
sleep 8

# 启动Flask管理平台
python3 /app/web-app/app.py
