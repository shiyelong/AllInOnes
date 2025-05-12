// Package sms 提供短信验证码相关功能
// 包含发送短信验证码、验证短信验证码等功能
package sms

import (
	"allinone_backend/utils"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// SMSVerification 短信验证码结构
// 包含手机号码、验证码、过期时间和使用状态
type SMSVerification struct {
	PhoneNumber string    // 手机号码
	Code        string    // 验证码
	ExpireTime  time.Time // 过期时间
	Used        bool      // 是否已使用
}

// smsVerificationMap 存储验证码的内存映射
// 实际生产环境应该使用Redis等分布式缓存系统存储验证码
// 键为手机号码，值为验证码信息
var smsVerificationMap = make(map[string]SMSVerification)

// GenerateSMSVerificationHandler 处理短信验证码生成请求
// 这个实现支持用户自己发送短信到运营商获取验证码
// 参数:
//   - c: Gin上下文，包含HTTP请求和响应信息
//
// 流程:
//  1. 从请求中获取手机号
//  2. 生成随机6位数验证码
//  3. 生成短信内容和目标号码
//  4. 存储验证码信息到内存映射和通用验证码存储
//  5. 返回短信内容和目标号码给用户
func GenerateSMSVerificationHandler(c *gin.Context) {
	// 从请求中获取手机号
	phoneNumber := c.Query("phone")
	if phoneNumber == "" {
		// 手机号为空，返回错误响应
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "手机号不能为空",
		})
		return
	}

	// 生成随机6位数验证码
	// 使用当前时间作为随机数种子，确保每次生成的验证码不同
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	verificationCode := fmt.Sprintf("%06d", r.Intn(1000000))

	// 生成短信内容和目标号码
	// 短信内容包含验证码和有效期
	smsContent := fmt.Sprintf("您的验证码是: %s，请在5分钟内完成验证。", verificationCode)
	targetNumber := "10690" // 短信验证码接收号码，实际应根据运营商配置

	// 存储验证码信息到内存映射
	// 包含手机号、验证码、过期时间和使用状态
	smsVerificationMap[phoneNumber] = SMSVerification{
		PhoneNumber: phoneNumber,
		Code:        verificationCode,
		ExpireTime:  time.Now().Add(5 * time.Minute), // 验证码5分钟后过期
		Used:        false,                           // 初始状态为未使用
	}

	// 同时保存到通用验证码存储中
	// 这确保了与其他验证码系统（如邮箱验证码）的一致性
	codeKey := fmt.Sprintf("phone:%s", phoneNumber)
	utils.SaveVerificationCode(codeKey, verificationCode)

	// 在开发环境中，打印验证码，方便调试
	if gin.Mode() == gin.DebugMode {
		fmt.Printf("手机号 %s 的验证码: %s\n", phoneNumber, verificationCode)
	}

	// 返回用户需要发送的短信内容和目标号码
	// 返回成功响应，包含短信内容和目标号码
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "请发送短信获取验证码",
		"data": gin.H{
			"sms_content":    smsContent,
			"target_number":  targetNumber,
			"phone":          phoneNumber,
			"expire_minutes": 5,
		},
	})
}

// VerifySMSCode 验证短信验证码
// 参数:
//   - phoneNumber: 手机号码
//   - code: 用户输入的验证码
//
// 返回值:
//   - bool: 验证是否成功
func VerifySMSCode(phoneNumber, code string) bool {
	// 首先尝试使用通用验证码存储系统验证
	// 这支持与其他验证码系统的集成
	codeKey := fmt.Sprintf("phone:%s", phoneNumber)
	if utils.VerifyCode(codeKey, code) {
		return true
	}

	// 从内存映射中获取验证码信息
	verification, exists := smsVerificationMap[phoneNumber]
	if !exists {
		// 如果不存在该手机号的验证码记录，验证失败
		return false
	}

	// 检查验证码是否过期
	if time.Now().After(verification.ExpireTime) {
		// 验证码已过期，返回失败
		return false
	}

	// 检查验证码是否已使用
	// 每个验证码只能使用一次
	if verification.Used {
		return false
	}

	// 检查验证码是否匹配
	if verification.Code != code {
		return false
	}

	// 验证成功，标记验证码为已使用
	verification.Used = true
	smsVerificationMap[phoneNumber] = verification

	return true
}

// MockVerifySMSCode 验证短信验证码（仅用于开发环境）
// 参数:
//   - phoneNumber: 手机号码
//   - code: 用户输入的验证码
//
// 返回值:
//   - bool: 验证是否成功
//
// 注意: 此函数仅用于开发环境，生产环境应使用VerifySMSCode
func MockVerifySMSCode(phoneNumber, code string) bool {
	// 在开发环境中，使用通用验证码存储系统验证
	// 这确保了与正式验证逻辑的一致性
	codeKey := fmt.Sprintf("phone:%s", phoneNumber)
	return utils.VerifyCode(codeKey, code)
}
