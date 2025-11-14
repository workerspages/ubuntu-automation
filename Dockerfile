FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

USER root

# 设置时区和语言为简体中文
ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8

# 安装编译依赖和必要软件包
RUN apt-get update && apt-get install -y \
    locales \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    gcc \
    g++ \
    libffi-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    cron \
    sqlite3 \
    curl \
    && locale-gen zh_CN.UTF-8 \
    && update-locale LANG=zh_CN.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 升级 pip 和安装 wheel
RUN pip3 install --upgrade pip setuptools wheel

# 创建必要的目录
RUN mkdir -p /app/web-app /app/scripts /app/firefox-xpi /home/headless/Downloads /app/data

# 复制 requirements.txt 先
COPY web-app/requirements.txt /app/web-app/

# 安装Python依赖（分步安装，更容易调试）
RUN pip3 install --no-cache-dir Flask==3.0.0 && \
    pip3 install --no-cache-dir Flask-Login==0.6.3 && \
    pip3 install --no-cache-dir Flask-SQLAlchemy==3.1.1 && \
    pip3 install --no-cache-dir APScheduler==3.10.4 && \
    pip3 install --no-cache-dir requests==2.31.0 && \
    pip3 install --no-cache-dir selenium==4.15.2 && \
    pip3 install --no-cache-dir python-telegram-bot==20.7 && \
    pip3 install --no-cache-dir cryptography==41.0.7

# 复制Firefox扩展
COPY firefox-xpi/selenium-ide.xpi /app/firefox-xpi/

# 安装Firefox扩展
RUN mkdir -p /usr/lib/firefox/distribution/extensions && \
    cp /app/firefox-xpi/selenium-ide.xpi /usr/lib/firefox/distribution/extensions/

# 设置Firefox语言为简体中文
RUN mkdir -p /usr/lib/firefox/defaults/pref && \
    echo 'pref("intl.locale.requested", "zh-CN");' > /usr/lib/firefox/defaults/pref/language.js && \
    echo 'pref("intl.accept_languages", "zh-CN, zh, en");' >> /usr/lib/firefox/defaults/pref/language.js

# 复制Web应用和脚本
COPY web-app/ /app/web-app/
COPY scripts/ /app/scripts/

# 设置权限
RUN chmod +x /app/scripts/*.sh && \
    chmod +x /app/scripts/*.py && \
    chown -R 1001:0 /app /home/headless/Downloads

# 暴露Web端口
EXPOSE 5000

USER 1001

# 启动脚本
CMD ["/app/scripts/startup.sh"]
