#!/bin/bash

# 启动虚拟显示器提供图形环境
Xvfb :1 -screen 0 1280x720x24 &

# 启动 VNC 服务，保持图形桌面
/etc/init.d/vncserver start || true

sleep 5

export DISPLAY=:1

# 可选打开 AutoKey 界面方便观察与录制（可注释）
# nohup autokey-gtk &

# 启动 Flask 应用
python3 /app/web-app/app.py
