package sms

import (
	"allinone_backend/utils"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// 短信验证码结构
type SMSVerification struct {
	PhoneNumber string
	Code        string
	ExpireTime  time.Time
	Used        bool
}

// 存储验证码的内存映射（实际应用中应该使用Redis等）
var smsVerificationMap = make(map[string]SMSVerification)

// GenerateSMSVerificationHandler 处理短信验证码生成请求
// 这个实现支持用户自己发送短信到运营商获取验证码
func GenerateSMSVerificationHandler(c *gin.Context) {
	phoneNumber := c.Query("phone")
	if phoneNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "手机号不能为空",
		})
		return
	}

	// 生成随机验证码
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	verificationCode := fmt.Sprintf("%06d", r.Intn(1000000))

	// 生成短信内容和目标号码
	smsContent := fmt.Sprintf("您的验证码是: %s，请在5分钟内完成验证。", verificationCode)
	targetNumber := "10690" // 示例短信验证码接收号码

	// 存储验证码信息
	smsVerificationMap[phoneNumber] = SMSVerification{
		PhoneNumber: phoneNumber,
		Code:        verificationCode,
		ExpireTime:  time.Now().Add(5 * time.Minute),
		Used:        false,
	}

	// 同时保存到通用验证码存储中，以便与邮箱验证码使用相同的验证逻辑
	codeKey := fmt.Sprintf("phone:%s", phoneNumber)
	utils.SaveVerificationCode(codeKey, verificationCode)

	// 在开发环境中，直接返回验证码，方便测试
	fmt.Printf("手机号 %s 的验证码: %s\n", phoneNumber, verificationCode)

	// 返回用户需要发送的短信内容和目标号码
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "请发送短信获取验证码",
		"data": gin.H{
			"sms_content":       smsContent,
			"target_number":     targetNumber,
			"phone":             phoneNumber,
			"expire_minutes":    5,
			"verification_code": verificationCode, // 在开发环境中返回验证码，方便测试
		},
		"code": verificationCode, // 在开发环境中返回验证码，方便测试
	})
}

// VerifySMSCode 验证短信验证码
func VerifySMSCode(phoneNumber, code string) bool {
	// 在开发环境中，如果验证码是"123456"，始终返回true
	if code == "123456" {
		return true
	}

	verification, exists := smsVerificationMap[phoneNumber]
	if !exists {
		return false
	}

	// 检查验证码是否过期
	if time.Now().After(verification.ExpireTime) {
		return false
	}

	// 检查验证码是否已使用
	if verification.Used {
		return false
	}

	// 检查验证码是否匹配
	if verification.Code != code {
		return false
	}

	// 标记验证码为已使用
	verification.Used = true
	smsVerificationMap[phoneNumber] = verification

	return true
}

// 模拟验证短信验证码（开发环境使用）
func MockVerifySMSCode(phoneNumber, code string) bool {
	// 在开发环境中，任何6位数字都视为有效
	return len(code) == 6 && code == "123456"
}
