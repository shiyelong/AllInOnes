# AllInOne 后端部署指南

本文档提供了将AllInOne后端部署到Cloudflare的详细步骤。

## 前提条件

1. 拥有Cloudflare账号
2. 已安装Docker和Docker Compose
3. 已安装Git

## 部署步骤

### 1. 克隆代码库

```bash
git clone https://github.com/yourusername/allinone.git
cd allinone/backend
```

### 2. 构建Docker镜像

```bash
docker build -t allinone-backend:latest .
```

### 3. 登录Cloudflare容器注册表

```bash
# 安装Cloudflare Wrangler CLI
npm install -g wrangler

# 登录Cloudflare
wrangler login

# 登录Cloudflare容器注册表
docker login registry.cloudflare.com
```

### 4. 标记并推送镜像到Cloudflare

```bash
# 替换<your-account-id>为您的Cloudflare账号ID
docker tag allinone-backend:latest registry.cloudflare.com/<your-account-id>/allinone-backend:latest
docker push registry.cloudflare.com/<your-account-id>/allinone-backend:latest
```

### 5. 创建Cloudflare Workers配置文件

创建一个名为`wrangler.toml`的文件：

```toml
name = "allinone-backend"
type = "webpack"
account_id = "<your-account-id>"
workers_dev = true
route = "<your-domain>/api/*"
zone_id = "<your-zone-id>"

[env.production]
workers_dev = false
route = "<your-production-domain>/api/*"
```

### 6. 部署到Cloudflare Workers

```bash
wrangler publish --env production
```

### 7. 配置数据库

AllInOne后端使用SQLite数据库，您需要确保数据库文件在Cloudflare Workers中可访问。

对于持久化存储，建议使用Cloudflare D1数据库或Cloudflare KV存储。

#### 使用Cloudflare D1数据库

1. 创建D1数据库：

```bash
wrangler d1 create allinone-db
```

2. 更新`wrangler.toml`文件，添加D1数据库配置：

```toml
[[d1_databases]]
binding = "DB"
database_name = "allinone-db"
database_id = "<database-id>"
```

3. 修改后端代码，使用D1数据库而不是SQLite。

### 8. 配置环境变量

在Cloudflare Workers的环境变量中设置以下值：

- `JWT_SECRET`: JWT签名密钥
- `EMAIL_HOST`: 邮件服务器主机
- `EMAIL_PORT`: 邮件服务器端口
- `EMAIL_USERNAME`: 邮件服务器用户名
- `EMAIL_PASSWORD`: 邮件服务器密码
- `EMAIL_FROM`: 发件人邮箱

### 9. 配置WebSocket

Cloudflare Workers支持WebSocket连接，但需要特殊配置：

1. 在`wrangler.toml`中添加：

```toml
[triggers]
crons = []

[durable_objects]
bindings = [
  { name = "WEBSOCKET_DO", class_name = "WebSocketDurableObject" }
]

[[migrations]]
tag = "v1"
new_classes = ["WebSocketDurableObject"]
```

2. 实现WebSocket Durable Object类。

### 10. 监控和日志

部署完成后，您可以通过Cloudflare Dashboard监控应用性能和查看日志。

## 故障排除

### 常见问题

1. **数据库连接失败**：
   - 检查D1数据库配置是否正确
   - 确保数据库绑定名称与代码中使用的一致

2. **WebSocket连接失败**：
   - 确保Durable Objects配置正确
   - 检查WebSocket路由是否正确配置

3. **邮件发送失败**：
   - 检查邮件服务器配置
   - 确保环境变量设置正确

### 获取帮助

如果您遇到任何问题，请联系我们的技术支持团队或在GitHub上提交Issue。

## 安全注意事项

1. 不要在代码中硬编码敏感信息，使用环境变量
2. 定期更新依赖包以修复安全漏洞
3. 使用HTTPS确保通信安全
4. 实施适当的访问控制和认证机制

## 性能优化

1. 使用Cloudflare缓存静态资源
2. 优化数据库查询
3. 实现适当的缓存策略
4. 使用Cloudflare Workers的边缘计算能力
