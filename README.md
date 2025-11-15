
# Ubuntu Automation - 您的个人自动化任务管理平台 🤖

[![构建状态](https://github.com/workerspages/ubuntu-automation/actions/workflows/docker-build.yml/badge.svg)](https://github.com/workerspages/ubuntu-automation/actions/workflows/docker-build.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/yourdockerhub/ubuntu-automation.svg)](https://hub.docker.com/r/yourdockerhub/ubuntu-automation) <!-- 请替换为您的 Docker Hub 链接 -->
[![GitHub 许可证](https://img.shields.io/github/license/workerspages/ubuntu-automation)](https://github.com/workerspages/ubuntu-automation/blob/main/LICENSE)

`ubuntu-automation` 是一个开箱即用的 Docker 化自动化解决方案。它将一个完整的带有图形界面的 Ubuntu 桌面环境、强大的 Web 管理面板和灵活的任务调度系统整合在一起，让您可以通过网页轻松管理和监控您的自动化脚本。

无论您是想执行定时的网页签到、数据抓取，还是运行复杂的桌面自动化流程，这个平台都能为您提供稳定、可视化的运行环境。

---

### ✨ 最新功能

*   **增强型 Selenium 执行器**: 内置强大的反机器人检测机制（修改 `navigator.webdriver` 属性、模拟人类输入延迟等），大幅提高 `.side` 脚本在复杂网站上的执行成功率。
*   **多架构 Docker 镜像**: 通过 GitHub Actions 自动构建并发布 `linux/amd64` 和 `linux/arm64` 镜像，完美支持 x86 服务器及 Apple M1/M2、树莓派等 ARM 设备。
*   **优化的 UI 界面**: 全新设计的 Web 管理界面，支持任务的实时增删改查，并提供 Cron 表达式预设按钮，新手也能轻松上手。
*   **支持 AutoKey**: 除了 Selenium 浏览器自动化，现在还支持 AutoKey 脚本，可实现更复杂的桌面级自动化操作。
*   **内置 Telegram 通知**: 只需简单配置，任务执行成功或失败后会自动发送通知到您的 Telegram，让您随时掌握任务状态。

---

### 🚀 核心特性

*   🖥️ **可视化操作**: 内置 VNC 和 noVNC（网页版 VNC），可随时通过浏览器实时查看和操作容器内的桌面环境，调试脚本从未如此简单。
*   🌐 **Web 管理面板**: 提供美观易用的 Web UI，用于添加、编辑、删除和手动触发自动化任务。
*   🕒 **Cron 任务调度**: 基于 Cron 表达式设置任务的执行周期，支持从分钟级到年级的任意调度策略。
*   🖱️ **支持多种脚本**:
    *   **Selenium IDE (`.side`)**: 直接运行由 Selenium IDE 录制的项目文件。
    *   **AutoKey (`.py`, `.autokey`)**: 执行键盘鼠标自动化脚本，胜任浏览器之外的任务。
*   📦 **一键部署**: 所有环境和依赖都已打包在 Docker 镜像中，使用 `docker-compose` 即可一键启动所有服务。
*   🔔 **实时通知**: 集成 Telegram Bot，在任务完成后即时推送结果，让您对自动化流程了如指掌。

---

### 🛠️ 部署指南

部署平台仅需简单四步。请确保您的服务器已安装 `Git`、`Docker` 和 `Docker Compose`。

#### 第 1 步：克隆项目仓库

```bash
git clone https://github.com/workerspages/ubuntu-automation.git
cd ubuntu-automation
```

#### 第 2 步：创建目录和放置脚本

您需要手动创建用于数据持久化的目录，并将您的自动化脚本放入指定位置。

```bash
# 创建用于存放数据库和日志的目录
mkdir -p data

# 创建用于存放 Selenium, AutoKey 脚本的目录
# 这里是您需要上传脚本的地方！
mkdir -p Downloads
```

**重要**: 将您编写或录制的 `.side`, `.py`, `.autokey` 脚本文件放入刚刚创建的 `Downloads` 目录中。Web 管理界面会自动扫描并加载此目录下的所有支持的脚本。

#### 第 3 步：配置环境变量

打开 `docker-compose.yml` 文件，根据您的需求修改 `environment` 部分的配置。

```yaml
version: '3.8'

services:
  ubuntu-automation:
    # 推荐使用 ghcr.io 镜像，更新更及时
    image: ghcr.io/workerspages/ubuntu-automation:latest
    container_name: ubuntu-automation
    # ... 其他配置 ...
    environment:
      # --- 基础配置 ---
      - VNC_PW=your_vnc_password          # 设置VNC访问密码
      - ADMIN_USERNAME=admin              # 设置Web后台登录用户名
      - ADMIN_PASSWORD=your_admin_password # 设置Web后台登录密码
      - SECRET_KEY=change-this-secret-key # Flask 应用的密钥，建议修改为一个随机字符串

      # --- Telegram 通知配置 (可选) ---
      - TELEGRAM_BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN # 你的 Telegram Bot Token
      - TELEGRAM_CHAT_ID=YOUR_TELEGRAM_CHAT_ID     # 你的 Telegram Chat ID
      
      # --- 高级配置 (通常无需修改) ---
      - DISPLAY=:1
```

**如何获取 Telegram 配置？**
1.  **Bot Token**: 在 Telegram 中与 `@BotFather` 对话，创建一个新的机器人即可获得 Token。
2.  **Chat ID**: 与您创建的机器人对话，然后访问 `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`，在返回的 JSON 中找到 `chat` -> `id`。

#### 第 4 步：启动服务

完成配置后，在项目根目录下执行以下命令以后台模式启动所有服务。

```bash
docker-compose up -d
```

服务启动后，您可以通过以下地址访问平台：
*   **Web 管理平台**: `http://<您的服务器IP>:5000`
*   **noVNC 网页桌面**: `http://<您的服务器IP>:6901`

---

### 📖 使用教程

1.  **登录管理平台**
    *   访问 `http://<您的服务器IP>:5000`，使用您在 `docker-compose.yml` 中设置的 `ADMIN_USERNAME` 和 `ADMIN_PASSWORD` 登录。

    ![登录界面](https://your-image-host.com/login.png) <!-- 建议替换为真实的截图 -->

2.  **访问 VNC 桌面 (可选)**
    *   访问 `http://<您的服务器IP>:6901`，输入您设置的 `VNC_PW` 密码，即可进入容器的图形化桌面。您可以在此手动运行或调试脚本。

    ![VNC 桌面](https://your-image-host.com/vnc-desktop.png) <!-- 建议替换为真实的截图 -->

3.  **添加一个定时任务**
    *   在 Dashboard 页面，点击右上角的 **"+ 添加任务"** 按钮。
    *   **任务名称**: 为您的任务起一个容易识别的名字（例如：“每日知乎签到”）。
    *   **选择脚本**: 在下拉菜单中选择您已放入 `Downloads` 文件夹的脚本。
    *   **定时执行**:
        *   点击预设按钮（如“每天9点”）可快速填充。
        *   或手动输入 Cron 表达式。例如 `0 2 * * *` 表示每天凌晨2点执行。
    *   点击 **"保存"**，任务就会被添加到调度队列中。

    ![添加任务](https://your-image-host.com/add-task-modal.png) <!-- 建议替换为真实的截图 -->

4.  **管理任务**
    *   **编辑**: 修改任务的名称或执行时间。
    *   **立即执行**: 手动触发一次任务，方便测试。执行过程可以在 VNC 桌面中实时观察。
    *   **删除**: 永久移除任务。

---

### ⚙️ 详细配置参考

以下是 `docker-compose.yml` 中所有可用环境变量的详细说明：

| 环境变量               | 描述                                             | 默认值/示例            |
| ---------------------- | ------------------------------------------------ | ---------------------- |
| `VNC_PW`               | VNC 和 noVNC 的访问密码。                        | `vncpassword`          |
| `ADMIN_USERNAME`       | Web 管理平台的管理员用户名。                     | `admin`                |
| `ADMIN_PASSWORD`       | Web 管理平台的管理员密码。                       | `vncpassword`          |
| `SECRET_KEY`           | Flask 应用的安全密钥，强烈建议修改。             | `your-secret-key-here` |
| `TELEGRAM_BOT_TOKEN`   | Telegram Bot 的 API Token，用于发送通知。        | (空)                   |
| `TELEGRAM_CHAT_ID`     | 接收通知的 Telegram 用户或频道的 Chat ID。     | (空)                   |
| `TZ`                   | 容器的系统时区，确保 Cron 任务按时执行。         | `Asia/Shanghai`        |
| `LANG`                 | 系统语言环境。                                   | `zh_CN.UTF-8`          |
| `DISPLAY`              | 指定图形界面输出到哪个显示器，通常无需修改。     | `:1`                   |
| `SCHEDULER_TIMEZONE`   | APScheduler 调度器的时区。                       | `Asia/Shanghai`        |

---

### 🧑‍💻 致开发者

我们欢迎任何形式的贡献！如果您有好的想法或发现了 Bug，请随时提交 Pull Request 或 Issue。

*   **项目结构**:
    *   `Dockerfile`: 定义了基础环境和所有依赖。
    *   `docker-compose.yml`: 用于快速部署和编排服务。
    *   `web-app/`: Flask 后端应用和前端模板。
    *   `scripts/`: 存放启动脚本 (`startup.sh`) 和任务执行器 (`task_executor.py`)。
    *   `.github/workflows/`: GitHub Actions CI/CD 配置，负责自动构建和发布 Docker 镜像。

### 🙏 致谢

*   本项目基于优秀的 [accetto/ubuntu-vnc-xfce-firefox-g3](https://github.com/accetto/headless-coding-g3) 基础镜像构建。
*   感谢所有为 Flask, Selenium, APScheduler 等开源库做出贡献的开发者。

### 📄 许可证

本项目采用 [MIT License](https://github.com/workerspages/ubuntu-automation/blob/main/LICENSE) 开源。
