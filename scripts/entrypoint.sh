#!/bin/bash
set -e

# 以 headless 用户身份（拥有免密sudo权限）执行
# 使用 sudo 执行所有需要 root 权限的初始化任务
echo "--- Running initialization as root via sudo ---"
sudo --non-interactive /bin/bash <<'EOF'
set -x

# --- 文件系统和权限准备 ---
# 1. 确保 supervisor 日志目录存在并有正确权限
mkdir -p /var/log/supervisor
chown headless:headless /var/log/supervisor

# 2. 确保 /app/data 目录存在且 headless 用户可写
mkdir -p /app/data
chown -R headless:headless /app/data

# --- VNC 和 X11 桌面环境准备 ---
# 3. 创建 VNC 密码文件（如果不存在）
if [ ! -f "/home/headless/.vncpasswd" ]; then
  echo "创建 VNC 密码文件..."
  mkdir -p /home/headless/.vnc
  echo "${VNC_PW:-vncpassword}" | vncpasswd -f > "/home/headless/.vncpasswd"
  chmod 600 "/home/headless/.vncpasswd"
  chown -R headless:headless /home/headless/.vnc
fi

# 4. 为 X11 显示服务创建授权凭证
touch /home/headless/.Xauthority
chown headless:headless /home/headless/.Xauthority
sudo -u headless bash -c "xauth add :1 . $(mcookie)"

# 5. 清理旧的 X11 锁文件
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# --- Nginx 准备 ---
# 6. 确保 Nginx 默认配置不冲突
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

EOF

# --- 启动 Supervisor 作为主进程 ---
# 【关键修复】使用 -E 参数告诉 sudo 保留现有的环境变量
echo "--- Initialization complete. Starting supervisord... ---"
exec sudo -E /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
