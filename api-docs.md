# ALLInOne 项目接口文档

## 认证模块（注册/登录/第三方登录）

### 1. 手机号注册
- **接口地址**：`POST /api/auth/register/phone`
- **请求参数**：
  | 字段      | 类型   | 必填 | 说明     |
  |-----------|--------|------|----------|
  | phone     | string | 是   | 手机号    |
  | code      | string | 是   | 验证码    |
  | password  | string | 是   | 密码      |
- **响应示例**：
  ```json
  { "success": true, "msg": "注册成功" }
  ```

### 2. 邮箱注册
- **接口地址**：`POST /api/auth/register/email`
- **请求参数**：
  | 字段      | 类型   | 必填 | 说明     |
  |-----------|--------|------|----------|
  | email     | string | 是   | 邮箱      |
  | code      | string | 是   | 验证码    |
  | password  | string | 是   | 密码      |
- **响应示例**：
  ```json
  { "success": true, "msg": "注册成功" }
  ```

### 3. 发送验证码（本地模拟）
- **接口地址**：`POST /api/auth/send_code`
- **请求参数**：
  | 字段      | 类型   | 必填 | 说明                 |
  |-----------|--------|------|----------------------|
  | phone/email | string | 是   | 手机号或邮箱         |
  | type      | string | 是   | "phone" 或 "email"   |
- **响应示例**：
  ```json
  { "success": true, "code": "123456" }
  ```

### 4. 第三方登录（本地模拟）
- **接口地址**：`POST /api/auth/login/third_party`
- **请求参数**：
  | 字段      | 类型   | 必填 | 说明           |
  |-----------|--------|------|----------------|
  | provider  | string | 是   | 第三方平台（如 wechat/qq/apple/google） |
- **响应示例**：
  ```json
  { "success": true, "msg": "登录成功", "provider": "wechat" }
  ```

---

> 后续接口（如登录、找回密码、用户信息、聊天、论坛等）请参见各模块目录及代码注释，或补充于本文件。

---

如需补充详细字段、状态码、错误码或 RESTful 风格说明，请告知。
