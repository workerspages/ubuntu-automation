# 使用包含 VNC、XFCE 和 Firefox 的 Ubuntu 基础镜像
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 切换到 root 用户以进行系统级安装和配置
USER root

# 设置环境变量，包括时区、语言、数据库和应用配置
ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    DATABASE_URL=sqlite:////app/data/tasks.db \
    SQLALCHEMY_DATABASE_URI=sqlite:////app/data/tasks.db \
    SQLALCHEMY_TRACK_MODIFICATIONS=false \
    SCHEDULER_TIMEZONE=Asia/Shanghai \
    SCHEDULER_API_ENABLED=true \
    SCRIPTS_DIR=/home/headless/Downloads \
    MAX_SCRIPT_TIMEOUT=300 \
    RETRY_FAILED_TASKS=true \
    MAX_RETRIES=3 \
    LOG_LEVEL=INFO \
    LOG_FILE=/app/data/automation.log \
    FIREFOX_BINARY=/usr/bin/firefox \
    GECKODRIVER_PATH=/usr/bin/geckodriver \
    FLASK_ENV=production \
    FLASK_DEBUG=false \
    HOST=0.0.0.0 \
    PORT=5000 \
    DISPLAY=:1

# --- 软件包安装 ---
# 分步安装以提高可读性和错误隔离
# 步骤 1: 更新软件源并安装核心依赖 (Nginx, Supervisor, Python, 图形界面基础)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor \
    locales fonts-wqy-microhei fonts-wqy-zenhei curl wget ca-certificates sudo git cron sqlite3 \
    python3 python3-pip python3-venv python3-dev build-essential pkg-config gcc g++ make libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev libpng-dev \
    python3-gi gir1.2-gtk-3.0 xvfb xfce4-session xfce4-panel xfce4-terminal xfce4-appfinder xfce4-settings dbus-x11 \
    libgtk-3-0 x11-xserver-utils openbox

# 步骤 2: 安装可选的包，使用 || true 忽略可能发生的错误
RUN apt-get install -y --no-install-recommends language-pack-zh-hans || true
RUN apt-get install -y --no-install-recommends fonts-noto-cjk fonts-noto-cjk-extra || true
RUN apt-get install -y --no-install-recommends python3-full || true
RUN apt-get install -y --no-install-recommends libgl1-mesa-glx libegl1-mesa libpci3 mesa-utils || true
RUN apt-get install -y --no-install-recommends gsettings-desktop-schemas dconf-cli gnome-icon-theme policykit-1 fuse python3-websockify xautomation x11-utils x11-apps kdialog imagemagick || true

# 步骤 3: 清理 apt 缓存
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# 配置中文环境
RUN locale-gen zh_CN.UTF-8 && update-locale LANG=zh_CN.UTF-8

# 配置 X11 允许所有用户连接
RUN mkdir -p /tmp/.X11-unix /tmp/.ICE-unix && chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# 创建应用所需目录
RUN mkdir -p /home/root && \
    mkdir -p /home/headless /app/web-app /app/scripts /home/headless/Downloads /app/data /app/logs && \
    ln -sf /home/headless/.Xauthority /home/root/.Xauthority 2>/dev/null || true

# 切换工作目录
WORKDIR /tmp

# 安装 AutoKey
RUN wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-common_0.96.0_all.deb \
    && wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-gtk_0.96.0_all.deb \
    && wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-qt_0.96.0_all.deb \
    && dpkg -i autokey-common_0.96.0_all.deb autokey-gtk_0.96.0_all.deb autokey-qt_0.96.0_all.deb || apt-get install -f -y \
    && rm -f autokey-common_0.96.0_all.deb autokey-gtk_0.96.0_all.deb autokey-qt_0.96.0_all.deb

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc

# 安装 Cloudflare Tunnel
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb || apt-get install -f -y && \
    rm -f cloudflared-linux-amd64.deb

# 清理临时文件
RUN rm -rf /tmp/* /var/tmp/*

# 创建 Python 虚拟环境
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装 Python 依赖
COPY web-app/requirements.txt /app/web-app/
RUN pip install --no-cache-dir wheel setuptools && pip install --no-cache-dir -r /app/web-app/requirements.txt

# 复制应用代码和配置文件
COPY firefox-xpi /app/firefox-xpi/
COPY web-app/ /app/web-app/
COPY scripts/ /app/scripts/
COPY nginx.conf /etc/nginx/nginx.conf

# 为 Firefox 安装 Selenium IDE 插件
RUN mkdir -p /usr/lib/firefox/distribution && \
    cp /app/firefox-xpi/selenium-ide.xpi /usr/lib/firefox/distribution/ && \
    echo '{' > /usr/lib/firefox/distribution/policies.json && \
    echo '  "policies": {' >> /usr/lib/firefox/distribution/policies.json && \
    echo '    "Extensions": {' >> /usr/lib/firefox/distribution/policies.json && \
    echo '      "Install": [' >> /usr/lib/firefox/distribution/policies.json && \
    echo '        "file:///usr/lib/firefox/distribution/selenium-ide.xpi"' >> /usr/lib/firefox/distribution/policies.json && \
    echo '      ]' >> /usr/lib/firefox/distribution/policies.json && \
    echo '    },' >> /usr/lib/firefox/distribution/policies.json && \
    echo '    "ExtensionSettings": {' >> /usr/lib/firefox/distribution/policies.json && \
    echo '      "*": {' >> /usr/lib/firefox/distribution/policies.json && \
    echo '        "installation_mode": "allowed",' >> /usr/lib/firefox/distribution/policies.json && \
    echo '        "blocked_install_message": "Custom addons are disabled"' >> /usr/lib/firefox/distribution/policies.json && \
    echo '      }' >> /usr/lib/firefox/distribution/policies.json && \
    echo '    }' >> /usr/lib/firefox/distribution/policies.json && \
    echo '  }' >> /usr/lib/firefox/distribution/policies.json && \
    echo '}' >> /usr/lib/firefox/distribution/policies.json

# 配置一个健壮的 VNC 启动脚本 (xstartup)，这个脚本将被基础镜像自动调用
RUN \
    mkdir -p /home/headless/.vnc && \
    cat <<EOF > /home/headless/.vnc/xstartup
#!/bin/sh
#
# This script is executed by vncserver and is responsible for
# launching the user's desktop environment.

# Unset session variables to avoid issues with stale sessions
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Load X resources (fonts, colors, etc.)
[ -r /etc/X11/Xresources ] && xrdb /etc/X11/Xresources

# Start the full XFCE4 Desktop Environment
# This is the key command that loads the panel, window manager, and desktop.
/usr/bin/startxfce4
EOF

# 确保脚本是可执行的
RUN chmod +x /home/headless/.vnc/xstartup

# 配置 XFCE 电源管理器，禁用屏幕关闭
RUN mkdir -p /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '<channel name="xfce4-power-manager" version="1.0">' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="xfce4-power-manager" type="empty">' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="blank-on-ac" type="int" value="0"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="blank-on-battery" type="int" value="0"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="dpms-enabled" type="bool" value="false"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="dpms-on-ac-sleep" type="uint" value="0"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="dpms-on-ac-off" type="uint" value="0"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  </property>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '</channel>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml

# 配置 XFCE 屏幕保护，禁用
RUN mkdir -p /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '<channel name="xfce4-screensaver" version="1.0">' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '  <property name="saver" type="empty">' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '    <property name="enabled" type="bool" value="false"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '    <property name="mode" type="int" value="0"/>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '  </property>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && \
    echo '</channel>' >> /home/headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml

# 设置最终的文件权限
RUN chmod +x /app/scripts/*.sh && \
    chown -R 1001:1001 /app /opt/venv /home/headless && \
    chown -R www-data:www-data /var/log/nginx /var/lib/nginx

# 仅暴露 Nginx 的 5000 端口
EXPOSE 5000

# 容器启动命令，使用新的 entrypoint 脚本来启动 Supervisor
# Supervisor 会管理 Nginx, noVNC 和 Gunicorn(Flask) 服务
CMD ["/app/scripts/entrypoint.sh"]
