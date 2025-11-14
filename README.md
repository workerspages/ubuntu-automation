# Ubuntu Automation - Selenium IDE 定时任务管理平台

基于 Ubuntu + VNC + Firefox + Selenium IDE 的自动化任务调度系统。

## 功能特性

- 🖥️ 完整的 Ubuntu 桌面环境（VNC/noVNC）
- 🦊 Firefox 浏览器（简体中文）
- 🔧 预装 Selenium IDE 扩展
- 📅 可视化定时任务管理
- 📱 Telegram 通知支持
- 🐳 Docker 一键部署

## 快速开始

1. 克隆仓库
2. 配置 docker-compose.yml 中的环境变量
3. 运行 `docker-compose up -d`
4. 访问 http://localhost:5000

## 环境变量

| 变量 | 说明 | 必填 |
|------|------|------|
| SECRET_KEY | Flask 密钥 | 是 |
| TELEGRAM_BOT_TOKEN | Bot Token | 是 |
| TELEGRAM_CHAT_ID | Chat ID | 是 |
| VNC_PW | VNC 密码 | 是 |

## 许可证

MIT
