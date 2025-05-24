# 微信项目

这是一个基于现代Web技术开发的聊天应用程序，旨在提供类似微信的功能体验。

## 项目结构

- `assets/`: 静态资源文件
  - `images/`: 图片资源
- `chat_app/`: 主应用程序
  - `client/`: 前端客户端代码
  - `server/`: 后端服务器代码
  - `docker-compose.yml`: Docker 配置文件

## 开发环境设置

### 前提条件

- Node.js
- Docker 和 Docker Compose

### 启动项目

```bash
# 启动 Docker 容器
cd chat_app
docker-compose up

# 启动前端开发服务器
cd chat_app/client
npm install
npm run dev

# 启动后端服务器
cd chat_app/server
npm install
npm run dev
```

## 功能特性

- 实时消息通信
- 用户认证
- 联系人管理
- 多媒体消息支持

## 贡献指南

欢迎提交 Pull Request 和 Issue 来帮助改进这个项目。 