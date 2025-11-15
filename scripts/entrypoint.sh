#!/bin/bash
set -e

# --- 以 root 身份执行初始化 ---
# 切换到 root，因为需要写 /etc 和 /tmp 下的文件
sudo -E /bin/bash <<'EOF'
set -x

# 清理 X11 锁文件
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# 确保 Nginx 默认配置不冲突
rm -f /etc/nginx/sites-enabled/default

# 重新链接我们的配置
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# 确保 supervisor 日志目录存在
mkdir -p /var/log/supervisor
chown 1001:1001 /var/log/supervisor

# 创建 VNC 密码文件（如果不存在）
if [ ! -f "/home/headless/.vncpasswd" ]; then
  echo "创建 VNC 密码文件..."
  mkdir -p /home/headless/.vnc
  chown 1001:1001 /home/headless/.vnc
  echo "${VNC_PW:-vncpassword}" | vncpasswd -f > "/home/headless/.vncpasswd"
  chmod 600 "/home/headless/.vncpasswd"
  chown 1001:1001 "/home/headless/.vncpasswd"
fi
EOF

# --- 启动 Supervisor ---
# -n 选项让 supervisord 在前台运行，这是容器主进程的推荐做法
echo "所有初始化完成，启动 supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
