# Cloudflare 部署指南 - AllInOne 后端

由于本地磁盘空间不足，我们将使用 Cloudflare 的 Web 界面来部署后端。

## 准备工作

1. 确保您已登录 Cloudflare 账号
2. 准备好后端代码的 ZIP 压缩包

## 第一步：创建 Cloudflare Worker

1. 访问 [Cloudflare Workers & Pages](https://dash.cloudflare.com/134ae4c19beb3dacbe0b18e0a27673c5/workers-and-pages)
2. 点击 "Create application"
3. 选择 "Worker"
4. 为您的 Worker 命名，例如 "allinone-backend"
5. 点击 "Deploy" 创建一个基本的 Worker

## 第二步：配置 Worker

1. 在 Worker 详情页面，点击 "Settings" 标签
2. 在 "Variables" 部分，添加以下环境变量：
   - `JWT_SECRET`: 用于 JWT 签名的密钥，例如 `your_jwt_secret_key`
   - `EMAIL_HOST`: 邮件服务器主机，例如 `smtp.outlook.com`
   - `EMAIL_PORT`: 邮件服务器端口，例如 `587`
   - `EMAIL_USERNAME`: 邮件服务器用户名，例如 `126970540@outlook.com`
   - `EMAIL_PASSWORD`: 邮件服务器密码
   - `EMAIL_FROM`: 发件人邮箱，例如 `126970540@outlook.com`

3. 在 "Compatibility flags" 部分，启用以下标志：
   - `nodejs_compat`: 启用 Node.js 兼容性
   - `streams_enable_constructors`: 启用流构造函数

## 第三步：创建 D1 数据库

1. 在 Cloudflare 控制面板中，点击 "D1" 菜单
2. 点击 "Create database" 按钮
3. 为数据库命名，例如 "allinone-db"
4. 点击 "Create" 创建数据库

## 第四步：绑定 D1 数据库到 Worker

1. 返回到 Worker 详情页面，点击 "Settings" 标签
2. 在 "Bindings" 部分，点击 "Add binding"
3. 选择 "D1 database"
4. 为绑定命名，例如 `DB`
5. 选择您刚刚创建的数据库
6. 点击 "Save" 保存绑定

## 第五步：上传数据库架构

1. 在 D1 数据库详情页面，点击 "Query" 标签
2. 将以下 SQL 语句复制到查询编辑器中，然后点击 "Run query" 执行：

```sql
-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  nickname VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(255),
  avatar VARCHAR(255),
  gender VARCHAR(10) DEFAULT 'unknown',
  birthday VARCHAR(255),
  signature VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP,
  status VARCHAR(20) DEFAULT 'active',
  email_verified BOOLEAN DEFAULT 0,
  phone_verified BOOLEAN DEFAULT 0,
  generated_email VARCHAR(255)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_users_account ON users(account);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- 创建其他必要的表
-- 聊天消息表
CREATE TABLE IF NOT EXISTS chat_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id INTEGER NOT NULL,
  receiver_id INTEGER NOT NULL,
  group_id INTEGER,
  content TEXT,
  type VARCHAR(20) DEFAULT 'text',
  status VARCHAR(20) DEFAULT 'sent',
  created_at BIGINT,
  read_at BIGINT,
  extra TEXT
);

-- 好友关系表
CREATE TABLE IF NOT EXISTS friends (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  friend_id INTEGER NOT NULL,
  remark VARCHAR(255),
  status VARCHAR(20) DEFAULT 'normal',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, friend_id)
);

-- 好友请求表
CREATE TABLE IF NOT EXISTS friend_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id INTEGER NOT NULL,
  receiver_id INTEGER NOT NULL,
  message VARCHAR(255),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 群组表
CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(255) NOT NULL,
  creator_id INTEGER NOT NULL,
  avatar VARCHAR(255),
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) DEFAULT 'active'
);

-- 群组成员表
CREATE TABLE IF NOT EXISTS group_members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  role VARCHAR(20) DEFAULT 'member',
  nickname VARCHAR(255),
  join_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) DEFAULT 'active',
  UNIQUE(group_id, user_id)
);
```

## 第六步：修改 Worker 代码

1. 返回到 Worker 详情页面，点击 "Edit code" 按钮
2. 将后端代码上传到 Worker

由于 Cloudflare Workers 的限制，我们需要对后端代码进行一些修改：

1. 将 SQLite 数据库替换为 D1 数据库
2. 移除文件系统操作，使用 Cloudflare KV 或 R2 存储文件
3. 调整 WebSocket 实现，使用 Durable Objects

## 第七步：部署 Worker

1. 在 Worker 编辑器中，点击 "Save and deploy" 按钮
2. 等待部署完成

## 第八步：测试部署

1. 在 Worker 详情页面，点击 "Triggers" 标签
2. 记下您的 Worker 的 URL，例如 `https://allinone-backend.your-username.workers.dev`
3. 使用 API 测试工具（如 Postman）测试 API 端点

## 第九步：配置自定义域名（可选）

1. 在 Worker 详情页面，点击 "Triggers" 标签
2. 在 "Custom domains" 部分，点击 "Add Custom Domain"
3. 输入您的域名，例如 `api.yourdomain.com`
4. 按照说明配置 DNS 记录

## 第十步：更新前端配置

1. 修改前端代码中的 API 基础 URL，指向您的 Worker URL
2. 重新部署前端应用

## 故障排除

如果您遇到问题，请检查：

1. Worker 日志：在 Worker 详情页面，点击 "Logs" 标签
2. D1 数据库连接：确保数据库绑定正确
3. 环境变量：确保所有必要的环境变量都已设置

## 安全注意事项

1. 定期更改 JWT 密钥和邮件密码
2. 启用 Cloudflare 的安全功能，如 WAF 和 Bot Management
3. 监控 Worker 的使用情况和性能
