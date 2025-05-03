package register

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"fmt"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

// 新的注册请求结构
type NewRegisterRequest struct {
	Email            string `json:"email"`
	Phone            string `json:"phone"`
	Password         string `json:"password"`
	CaptchaID        string `json:"captcha_id"`
	CaptchaValue     string `json:"captcha_value"`
	VerificationCode string `json:"verification_code"` // 手机/邮箱验证码
	RegisterType     string `json:"register_type"`     // "email" 或 "phone"
	Nickname         string `json:"nickname"`          // 昵称（可选）
}

// 新的注册处理函数
func NewRegisterHandler(c *gin.Context) {
	var req NewRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证图形验证码
	if !utils.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "图形验证码错误"})
		return
	}

	// 验证手机/邮箱验证码
	var target string
	if req.RegisterType == "email" {
		target = req.Email
	} else {
		target = req.Phone
	}
	codeKey := fmt.Sprintf("%s:%s", req.RegisterType, target)
	if !utils.VerifyCode(codeKey, req.VerificationCode) {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "验证码错误或已过期"})
		return
	}

	// 验证注册类型
	if req.RegisterType != "email" && req.RegisterType != "phone" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "注册类型错误"})
		return
	}

	// 根据注册类型验证参数
	if req.RegisterType == "email" && req.Email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "邮箱不能为空"})
		return
	}

	if req.RegisterType == "phone" && req.Phone == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "手机号不能为空"})
		return
	}

	// 检查邮箱或手机号是否已存在
	var count int64
	if req.RegisterType == "email" {
		err := utils.DB.Model(&models.User{}).Where("email = ?", req.Email).Count(&count).Error
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "数据库错误"})
			return
		}
		if count > 0 {
			c.JSON(http.StatusOK, gin.H{"success": false, "msg": "邮箱已被注册"})
			return
		}
	} else {
		err := utils.DB.Model(&models.User{}).Where("phone = ?", req.Phone).Count(&count).Error
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "数据库错误"})
			return
		}
		if count > 0 {
			c.JSON(http.StatusOK, gin.H{"success": false, "msg": "手机号已被注册"})
			return
		}
	}

	// 密码加密
	hashedPwd, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "密码加密失败"})
		return
	}

	// 创建用户
	user := models.User{
		Password:      string(hashedPwd),
		CreatedAt:     time.Now().Unix(),
		FriendAddMode: 1, // 默认设置为需要验证
	}

	// 根据注册类型设置邮箱或手机号
	if req.RegisterType == "email" {
		// 检查是否使用公司邮箱注册
		if strings.HasSuffix(req.Email, "@allinone.com") {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不能使用公司邮箱注册"})
			return
		}
		user.Email = req.Email
		user.EmailVerified = true // 简化处理，实际应该通过邮箱验证
	} else {
		user.Phone = req.Phone
		user.PhoneVerified = true // 简化处理，实际应该通过短信验证
	}

	// 保存用户
	if err := utils.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "注册失败"})
		return
	}

	// 生成随机账号（6位数字，不按顺序）
	// 使用更新的随机数生成方法
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	randomNum := 100000 + r.Intn(900000) // 生成100000-999999之间的随机数
	account := strconv.Itoa(randomNum)

	// 生成AllInOne品牌的邮箱
	generatedEmail := account + "@allinone.com"

	// 设置昵称（如果用户提供了昵称，则使用用户提供的昵称，否则使用账号作为默认昵称）
	nickname := account
	if req.Nickname != "" {
		nickname = req.Nickname
	}

	// 更新用户账号和生成的邮箱
	if err := utils.DB.Model(&user).Updates(map[string]interface{}{
		"Account":        account,
		"GeneratedEmail": generatedEmail,
		"Nickname":       nickname,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新账号信息失败"})
		return
	}

	// 返回成功信息
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "注册成功",
		"data": gin.H{
			"account":         account,
			"generated_email": generatedEmail,
			"nickname":        nickname,
		},
	})
}

// 生成验证码处理函数
func GenerateVerificationCode(c *gin.Context) {
	codeType := c.Query("type") // "email" 或 "phone"
	target := c.Query("target") // 邮箱或手机号

	if codeType != "email" && codeType != "phone" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "验证码类型错误"})
		return
	}

	if target == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "目标不能为空"})
		return
	}

	// 生成6位随机验证码
	code := utils.GenerateRandomCode(6)

	// 保存验证码（实际应用中应该有过期时间）
	codeKey := fmt.Sprintf("%s:%s", codeType, target)
	utils.SaveVerificationCode(codeKey, code)

	// 根据类型发送验证码
	var err error
	if codeType == "email" {
		// 验证邮箱格式
		if !utils.ValidateEmail(target) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "邮箱格式不正确"})
			return
		}

		// 发送邮件验证码
		err = utils.SendVerificationEmail(target, code)
		if err != nil {
			fmt.Printf("发送邮件验证码失败: %v\n", err)
			// 在macOS测试环境中，如果发送失败，仍然返回成功，并在日志中打印验证码
			fmt.Printf("macOS测试环境 - 向邮箱 %s 发送验证码: %s\n", target, code)

			// 尝试使用本地邮件发送功能
			localEmailConfig := utils.EmailConfig{
				Host:     "localhost",
				Port:     25,
				Username: "",
				Password: "",
				From:     "noreply@localhost",
			}
			utils.SetEmailConfig(localEmailConfig)

			// 再次尝试发送
			err = utils.SendVerificationEmail(target, code)
			if err != nil {
				fmt.Printf("使用本地邮件服务发送失败: %v\n", err)
				// 返回验证码，方便测试
				c.JSON(http.StatusOK, gin.H{
					"success": true,
					"msg":     "验证码已发送（模拟）",
					"code":    code, // 在测试环境中返回验证码，方便测试
				})
				return
			}
		}
	} else {
		// 验证手机号格式
		if !utils.ValidatePhone(target) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "手机号格式不正确"})
			return
		}

		// 发送短信验证码
		err = utils.SendSMSVerificationCode(target, code)
		if err != nil {
			fmt.Printf("发送短信验证码失败: %v\n", err)
			// 在开发环境中，如果发送失败，仍然返回成功，并在日志中打印验证码
			fmt.Printf("开发环境 - 向手机 %s 发送验证码: %s\n", target, code)
			c.JSON(http.StatusOK, gin.H{
				"success": true,
				"msg":     "验证码已发送",
				"code":    code, // 在开发环境中返回验证码，方便测试
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "验证码已发送",
		// 在开发环境下返回验证码，方便测试
		"code": code,
	})
}
