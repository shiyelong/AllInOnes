# Full 项目快速启动与极致细分模块化开发规范

## 目录结构示例（极致细分，涵盖主要业务模块）

### 前端（Flutter）
```plaintext
frontend/
  lib/
    modules/
      auth/
        register/
          phone/
            phone_register_page.dart
            phone_register_controller.dart
            phone_register_service.dart
            phone_register_validator.dart
            phone_register_constants.dart
            phone_register_api.dart
            phone_register_events.dart
            phone_register_state.dart
            widgets/
              phone_register_form.dart
              phone_register_button.dart
              phone_register_code_input.dart
          email/
            email_register_page.dart
            email_register_controller.dart
            email_register_service.dart
            email_register_validator.dart
            email_register_constants.dart
            email_register_api.dart
            email_register_events.dart
            email_register_state.dart
            widgets/
              email_register_form.dart
              email_register_button.dart
          code/
            code_register_page.dart
            code_register_controller.dart
            code_register_service.dart
            code_register_validator.dart
            code_register_constants.dart
            code_register_api.dart
            code_register_events.dart
            code_register_state.dart
            widgets/
              code_register_form.dart
              code_register_button.dart
        login/
          phone/
            phone_login_page.dart
            phone_login_controller.dart
            phone_login_service.dart
            phone_login_validator.dart
            phone_login_constants.dart
            phone_login_api.dart
            phone_login_events.dart
            phone_login_state.dart
            widgets/
              phone_login_form.dart
              phone_login_button.dart
          email/
            email_login_page.dart
            email_login_controller.dart
            email_login_service.dart
            email_login_validator.dart
            email_login_constants.dart
            email_login_api.dart
            email_login_events.dart
            email_login_state.dart
            widgets/
              email_login_form.dart
              email_login_button.dart
          code/
            code_login_page.dart
            code_login_controller.dart
            code_login_service.dart
            code_login_validator.dart
            code_login_constants.dart
            code_login_api.dart
            code_login_events.dart
            code_login_state.dart
            widgets/
              code_login_form.dart
              code_login_button.dart
      chat/
        single/
          single_chat_page.dart
          single_chat_controller.dart
          single_chat_service.dart
          single_chat_events.dart
          single_chat_state.dart
          widgets/
            chat_input_box.dart
            chat_message_list.dart
        group/
          group_chat_page.dart
          group_chat_controller.dart
          group_chat_service.dart
          group_chat_events.dart
          group_chat_state.dart
          widgets/
            group_chat_input_box.dart
            group_chat_message_list.dart
        video/
          video_call_page.dart
          video_call_controller.dart
          video_call_service.dart
          video_call_events.dart
          video_call_state.dart
          widgets/
            video_call_toolbar.dart
      forum/
        post/
          post_list_page.dart
          post_detail_page.dart
          post_list_controller.dart
          post_detail_controller.dart
          post_service.dart
          post_model.dart
          post_events.dart
          post_state.dart
          widgets/
            post_card.dart
            post_action_bar.dart
        comment/
          comment_list_page.dart
          comment_item.dart
          comment_list_controller.dart
          comment_service.dart
          comment_events.dart
          comment_state.dart
          widgets/
            comment_input_box.dart
      mall/
        product/
          product_list_page.dart
          product_detail_page.dart
          product_list_controller.dart
          product_detail_controller.dart
          product_service.dart
          product_model.dart
          widgets/
            product_card.dart
            product_action_bar.dart
        cart/
          cart_page.dart
          cart_controller.dart
          cart_service.dart
          cart_model.dart
          widgets/
            cart_item.dart
      # ... 其它大模块继续极致细分
    widgets/
      loading_indicator.dart
      error_dialog.dart
      # ... 通用组件
    models/
      user_model.dart
      post_model.dart
      # ... 通用数据模型
    utils/
      network_util.dart
      date_util.dart
      # ... 通用工具
  pubspec.yaml
```

### 后端（Go）
```plaintext
backend/
  cmd/
    main.go
  internal/
    auth/
      register/
        phone/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
          middleware.go
        email/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
        code/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
      login/
        phone/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
        email/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
        code/
          handler.go
          service.go
          validator.go
          dto.go
          repo.go
          events.go
          constants.go
      util/
        password.go
        token.go
    chat/
      single/
        handler.go
        service.go
        events.go
        repo.go
        constants.go
        middleware.go
      group/
        handler.go
        service.go
        events.go
        repo.go
        constants.go
        middleware.go
      video/
        handler.go
        service.go
        events.go
        repo.go
        constants.go
        middleware.go
    forum/
      post/
        handler.go
        service.go
        repo.go
        dto.go
        events.go
        constants.go
      comment/
        handler.go
        service.go
        repo.go
        dto.go
        events.go
        constants.go
    mall/
      product/
        handler.go
        service.go
        repo.go
        dto.go
        events.go
        constants.go
      cart/
        handler.go
        service.go
        repo.go
        dto.go
        events.go
        constants.go
    # ... 其它大模块继续极致细分
  api/
    auth/
      register/
        phone_api.go
        email_api.go
        code_api.go
      login/
        phone_api.go
        email_api.go
        code_api.go
    chat/
      single_api.go
      group_api.go
      video_api.go
    forum/
      post_api.go
      comment_api.go
    mall/
      product_api.go
      cart_api.go
  config/
    config.yaml
  model/
    user.go
    post.go
    # ... 通用数据模型
  pkg/
    logger/
      logger.go
    middleware/
      auth.go
      cors.go
    # ... 通用公共包
  go.mod
```

## 极致细分开发规范
- 每个微功能下再细分为“页面/控制器/服务/校验/常量/事件/状态/组件”等，单一文件只做一件事。
- 后端每个 handler/service/validator/dto/repo/events/constants/middleware 独立文件，单一职责。
- 任何文件超过300-600行必须继续拆分。
- 目录结构递进到功能颗粒度极细，便于多人并行开发和后期重构。
- 公共方法、通用组件、工具、常量全部抽出单独目录和文件。
- API 层也按功能极致细分，便于接口聚合与拆分。
- 新增功能时，优先考虑能否继续细分，避免大文件。
- 前后端均建议遵循此规范，提升协作效率和可维护性。

## 项目初始化与快速启动

### 1. 初始化前端（Flutter）项目
项目名称为 ALLInOne，支持 Windows、MacOS、Linux、iOS、Android。

#### 创建 Flutter 多端项目
```bash
# 安装 Flutter（如未安装）
# 参考官方文档：https://docs.flutter.dev/get-started/install

# 创建项目（项目名 ALLInOne）
flutter create ALLInOne

# 启用所有桌面与移动端平台支持
cd ALLInOne
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
flutter create .

# 进入项目目录，获取依赖
flutter pub get

# 运行（根据平台选择）
flutter run -d windows   # Windows
flutter run -d macos     # MacOS
flutter run -d linux     # Linux
flutter run -d ios       # iOS
flutter run -d android   # Android
```

#### 目录调整
创建后，将 lib/ 目录结构调整为上述极致细分结构（可手动或脚本自动化）。

### 2. 初始化后端（Go）项目

```bash
# 创建后端目录
mkdir -p backend/cmd
cd backend

go mod init allinone_backend

# 推荐依赖（可根据业务扩展）
go get github.com/gin-gonic/gin
# ... 其它依赖

# 创建主入口文件
cat > cmd/main.go << EOF
package main
import "fmt"
func main() {
    fmt.Println("ALLInOne 后端服务启动成功！")
}
EOF

# 启动后端服务
cd ..
cd backend
go mod tidy
go run ./cmd/main.go
```

### 3. 其它说明
- 数据库（MySQL/Redis）等可按需初始化。
- 目录结构请严格按照极致细分规范搭建。
- 推荐使用 Git 进行版本管理。

---
更多详细功能和模块说明请参见主 README.md。
