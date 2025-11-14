#!/bin/bash
set -e

echo "====================================="
echo "启动 Selenium 自动化管理平台"
echo "====================================="

# 创建数据目录并确保权限正确
mkdir -p /app/data /app/logs
chmod 755 /app/data /app/logs

# 如果以 root 运行，切换目录所有权
if [ "$(id -u)" = "0" ]; then
    chown -R 1001:0 /app/data /app/logs
fi

# 后台启动 Web 应用
echo "启动 Web 应用..."
cd /app/web-app
nohup python3 app.py > /app/logs/webapp.log 2>&1 &
WEB_PID=$!
echo "Web 应用已启动，PID: $WEB_PID"

# 等待 Web 应用启动
sleep 3

# 检查 Web 应用是否运行
if ps -p $WEB_PID > /dev/null; then
    echo "Web 应用运行正常"
else
    echo "警告：Web 应用启动失败，查看日志："
    cat /app/logs/webapp.log
fi

echo "Web 界面: http://localhost:5000"
echo "VNC 界面: http://localhost:6901"
echo "====================================="

# 启动 VNC
if [ -f "/dockerstartup/vnc_startup.sh" ]; then
    exec /dockerstartup/vnc_startup.sh
else
    echo "保持容器运行..."
    tail -f /app/logs/webapp.log
fi
