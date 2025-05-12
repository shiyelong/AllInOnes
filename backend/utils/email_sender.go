package utils

import (
	"fmt"
	"net/smtp"
	"strings"

	"github.com/gin-gonic/gin"
)

// 邮件配置
type EmailConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
}

// 全局邮件配置
var emailConfig = EmailConfig{
	Host:     "smtp.qq.com",
	Port:     587,
	Username: "your_email@qq.com", // 替换为您的QQ邮箱
	Password: "your_password",     // 替换为您的邮箱授权码
	From:     "your_email@qq.com", // 替换为您的QQ邮箱
}

// 初始化函数，从环境变量或配置文件加载邮箱配置
func init() {
	// 这里可以从环境变量或配置文件加载邮箱配置
	// 为了简单起见，我们直接在代码中设置

	// 使用Outlook邮箱的SMTP服务
	// 注意：在实际使用时，请使用环境变量或配置文件存储这些敏感信息
	emailConfig = EmailConfig{
		Host:     "smtp.office365.com",    // Outlook SMTP服务器
		Port:     587,                     // Outlook SMTP端口
		Username: "126970540@outlook.com", // 发送邮箱
		Password: "your_password",         // 这里需要替换为邮箱的密码
		From:     "126970540@outlook.com", // 发送邮箱
	}

	// 初始化邮件服务
	fmt.Println("邮件服务初始化完成，发送邮箱：126970540@outlook.com")
}

// 设置邮件配置
func SetEmailConfig(config EmailConfig) {
	emailConfig = config
}

// 发送邮件
func SendEmail(to, subject, body string) error {
	// 构建邮件头
	headers := make(map[string]string)
	headers["From"] = emailConfig.From
	headers["To"] = to
	headers["Subject"] = subject
	headers["MIME-Version"] = "1.0"
	headers["Content-Type"] = "text/html; charset=UTF-8"

	// 构建邮件内容
	message := ""
	for key, value := range headers {
		message += fmt.Sprintf("%s: %s\r\n", key, value)
	}
	message += "\r\n" + body

	// 连接到SMTP服务器
	auth := smtp.PlainAuth("", emailConfig.Username, emailConfig.Password, emailConfig.Host)
	addr := fmt.Sprintf("%s:%d", emailConfig.Host, emailConfig.Port)

	// 发送邮件
	return smtp.SendMail(
		addr,
		auth,
		emailConfig.From,
		[]string{to},
		[]byte(message),
	)
}

// 发送验证码邮件
func SendVerificationEmail(to, code string) error {
	// 在测试环境中，我们总是保存验证码到内存中，以便后续验证
	codeKey := fmt.Sprintf("email:%s", to)
	SaveVerificationCode(codeKey, code)

	// 在开发环境中打印验证码，方便调试
	if gin.Mode() == gin.DebugMode {
		fmt.Printf("验证码已生成 - 目标邮箱: %s, 验证码: %s\n", to, code)
	}

	// 构建邮件内容
	subject := "验证码 - 您的账号注册"
	body := fmt.Sprintf(`
		<html>
		<body>
			<h2>验证码</h2>
			<p>您的验证码是: <strong>%s</strong></p>
			<p>验证码有效期为10分钟，请勿泄露给他人。</p>
			<p>如果这不是您的操作，请忽略此邮件。</p>
		</body>
		</html>
	`, code)

	// 尝试发送邮件
	err := SendEmail(to, subject, body)
	if err != nil {
		fmt.Printf("发送邮件失败: %v\n", err)

		// 即使发送失败，我们也返回nil，表示验证码已生成
		return nil
	}

	// 在开发环境中打印成功信息
	if gin.Mode() == gin.DebugMode {
		fmt.Printf("邮件发送成功，验证码: %s\n", code)
	}
	return nil
}

// 验证邮箱格式
func ValidateEmail(email string) bool {
	// 简单的邮箱格式验证
	return strings.Contains(email, "@") && strings.Contains(email, ".")
}
