FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

USER root

ENV TZ=Asia/Shanghai LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8 DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales fonts-wqy-microhei fonts-wqy-zenhei curl wget ca-certificates sudo git cron sqlite3 \
    language-pack-zh-hans fonts-noto-cjk fonts-noto-cjk-extra libgtk-3-0 x11-xserver-utils openbox x11-apps \
    python3 python3-pip python3-venv python3-dev build-essential pkg-config gcc g++ make libffi-dev libssl-dev libxml2-dev libxslt1-dev \
    zlib1g-dev libjpeg-dev libpng-dev python3-full python3-gi gir1.2-gtk-3.0 xvfb xfce4-session xfce4-panel xfce4-terminal \
    xfce4-appfinder xfce4-settings dbus-x11 libgl1-mesa-glx libegl1-mesa libpci3 mesa-utils gsettings-desktop-schemas \
    dconf-cli gnome-icon-theme policykit-1 fuse python3-websockify xautomation kdialog imagemagick

RUN mkdir -p /tmp/.X11-unix /tmp/.ICE-unix && chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

RUN mkdir -p /home/headless /app/web-app /app/scripts /home/headless/Downloads /app/data /app/logs
RUN chown -R 1001:1001 /home/headless /app/web-app /app/scripts /app/data /app/logs
RUN chmod -R u+rwX /home/headless

WORKDIR /tmp
RUN wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-common_0.96.0_all.deb \
 && wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-gtk_0.96.0_all.deb \
 && wget https://github.com/autokey/autokey/releases/download/v0.96.0/autokey-qt_0.96.0_all.deb \
 && dpkg -i autokey-common_0.96.0_all.deb autokey-gtk_0.96.0_all.deb autokey-qt_0.96.0_all.deb || apt-get install -f -y \
 && rm -f autokey-common_0.96.0_all.deb autokey-gtk_0.96.0_all.deb autokey-qt_0.96.0_all.deb

RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY web-app/requirements.txt /app/web-app/
RUN pip install --no-cache-dir wheel setuptools && pip install --no-cache-dir -r /app/web-app/requirements.txt

COPY web-app/ /app/web-app/
COPY scripts/ /app/scripts/

RUN chmod +x /app/scripts/*.sh /app/scripts/*.py && chown -R 1001:1001 /app /opt/venv

EXPOSE 5000 6901

USER 1001
CMD ["/app/scripts/startup.sh"]
