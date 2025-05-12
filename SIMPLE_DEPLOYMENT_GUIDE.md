# 简易 Cloudflare Worker 部署指南

由于磁盘空间不足，我们无法在本地构建和部署完整的后端。因此，我们将使用一个简单的 Cloudflare Worker 脚本作为临时解决方案。

## 部署步骤

1. 登录 Cloudflare 账号
2. 访问 Workers & Pages 页面
3. 创建一个新的 Worker
4. 将 `cloudflare-worker.js` 文件的内容复制到 Worker 编辑器中
5. 部署 Worker

## 详细步骤

### 1. 登录 Cloudflare 账号

使用您提供的凭证登录 Cloudflare 账号：
- 账号：1269705430@outlook.com
- 密码：Syl971005@

### 2. 访问 Workers & Pages 页面

在 Cloudflare 控制面板中，点击左侧菜单的 "Workers & Pages"。

### 3. 创建一个新的 Worker

1. 点击 "Create application" 按钮
2. 选择 "Worker" 选项
3. 为您的 Worker 命名，例如 "allinone-backend"
4. 点击 "Create Worker" 按钮

### 4. 编辑 Worker 代码

1. 在 Worker 编辑器中，删除默认的代码
2. 将 `cloudflare-worker.js` 文件的内容复制到编辑器中
3. 根据需要修改配置（如 JWT 密钥）

### 5. 部署 Worker

1. 点击 "Save and deploy" 按钮
2. 等待部署完成

### 6. 测试 Worker

1. 部署完成后，您将看到 Worker 的 URL，例如 `https://allinone-backend.your-username.workers.dev`
2. 使用浏览器访问 `https://allinone-backend.your-username.workers.dev/api/health` 进行测试
3. 如果一切正常，您将看到一个 JSON 响应，表示 Worker 已成功部署

### 7. 更新前端配置

1. 修改前端代码中的 API 基础 URL，指向您的 Worker URL
2. 重新部署前端应用

## 注意事项

1. 这个 Worker 脚本只是一个临时解决方案，它模拟了一些基本的 API 功能，如注册、登录和验证码
2. 它不包含完整的后端功能，也不连接到实际的数据库
3. 对于生产环境，您应该部署完整的后端服务

## 后续步骤

1. 清理磁盘空间
2. 安装必要的工具（Node.js、Docker 等）
3. 按照 `CLOUDFLARE_DEPLOYMENT_GUIDE.md` 中的说明部署完整的后端服务

## 安全注意事项

1. 部署完成后，立即更改 Cloudflare 账号密码
2. 启用双因素认证
3. 定期检查 Worker 的使用情况和性能
