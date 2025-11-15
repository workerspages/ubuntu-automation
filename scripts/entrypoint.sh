#!/bin/bash
set -e

# 以 headless 用户身份（拥有免密sudo权限）执行
# 使用 sudo 执行所有需要 root 权限的初始化任务
echo "--- Running initialization as root via sudo ---"
sudo --non-interactive /bin/bash <<'EOF'
set -x

# 清理 X11 锁文件
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# 确保 Nginx 默认配置不冲突
rm -f /etc/nginx/sites-enabled/default

# 重新链接我们的配置
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# 确保 supervisor 日志目录存在并有正确权限
mkdir -p /var/log/supervisor
chown headless:headless /var/log/supervisor

# 创建 VNC 密码文件（如果不存在）
if [ ! -f "/home/headless/.vncpasswd" ]; then
  echo "创建 VNC 密码文件..."
  mkdir -p /home/headless/.vnc
  chown headless:headless /home/headless/.vnc
  echo "${VNC_PW:-vncpassword}" | vncpasswd -f > "/home/headless/.vncpasswd"
  chmod 600 "/home/headless/.vncpasswd"
  chown headless:headless "/home/headless/.vncpasswd"
fi
EOF

# --- 启动 Supervisor 作为主进程 ---
# -n 选项让 supervisord 在前台运行，这是容器主进程的推荐做法
# supervisord 将以 root 身份运行，并根据配置降权启动各个子进程
echo "--- Initialization complete. Starting supervisord... ---"
exec sudo /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
