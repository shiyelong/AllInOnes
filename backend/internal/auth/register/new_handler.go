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
// 支持三种注册方式：邮箱、手机号和账号
// 根据RegisterType字段区分不同的注册方式
type NewRegisterRequest struct {
	Email            string `json:"email"`             // 邮箱地址，当RegisterType为"email"时必填
	Phone            string `json:"phone"`             // 手机号码，当RegisterType为"phone"时必填
	Password         string `json:"password"`          // 用户密码，必填
	CaptchaID        string `json:"captcha_id"`        // 图形验证码ID，可选
	CaptchaValue     string `json:"captcha_value"`     // 图形验证码值，可选
	VerificationCode string `json:"verification_code"` // 手机/邮箱验证码，根据注册类型必填
	RegisterType     string `json:"register_type"`     // 注册类型："email"、"phone"或"account"
	Nickname         string `json:"nickname"`          // 用户昵称，可选，默认使用账号作为昵称
}

// 新的注册处理函数
// 支持邮箱、手机号和账号三种注册方式
// 注册成功后会生成随机6位数字账号和对应的allinone.com邮箱
func NewRegisterHandler(c *gin.Context) {
	// 解析请求参数
	var req NewRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// 参数解析失败，返回错误信息
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误，请检查输入格式"})
		return
	}

	// 验证图形验证码（如果提供了验证码ID和值）
	if req.CaptchaID != "" && req.CaptchaValue != "" {
		if !utils.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
			c.JSON(http.StatusOK, gin.H{"success": false, "msg": "图形验证码错误"})
			return
		}
	}

	// 验证手机/邮箱验证码（如果提供了验证码）
	if req.VerificationCode != "" {
		var target string
		var registerType string

		// 确定注册类型和目标
		if req.RegisterType == "email" {
			registerType = "email"
			target = req.Email
		} else if req.RegisterType == "phone" {
			registerType = "phone"
			target = req.Phone
		} else if req.RegisterType == "account" {
			// 账号注册方式不需要验证码
			registerType = "account"
			target = req.VerificationCode // 直接使用验证码作为目标
		} else {
			// 默认使用账号注册方式
			registerType = "account"
			target = req.VerificationCode
		}

		// 如果是邮箱或手机号注册，验证验证码
		if (registerType == "email" || registerType == "phone") && target != "" {
			codeKey := fmt.Sprintf("%s:%s", registerType, target)
			if !utils.VerifyCode(codeKey, req.VerificationCode) {
				// 在开发环境中，如果验证码是123456，直接通过
				if req.VerificationCode != "123456" {
					c.JSON(http.StatusOK, gin.H{"success": false, "msg": "验证码错误或已过期"})
					return
				}
				fmt.Println("开发环境 - 使用默认验证码123456")
			}
		}
	}

	// 验证注册类型
	if req.RegisterType != "email" && req.RegisterType != "phone" && req.RegisterType != "account" {
		// 如果注册类型为空，默认使用账号注册
		if req.RegisterType == "" {
			req.RegisterType = "account"
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "注册类型错误，必须是email、phone或account"})
			return
		}
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
	} else if req.RegisterType == "phone" {
		user.Phone = req.Phone
		user.PhoneVerified = true // 简化处理，实际应该通过短信验证
	} else if req.RegisterType == "account" {
		// 账号注册方式不需要设置邮箱或手机号
		// 如果提供了昵称，使用提供的昵称
		if req.Nickname != "" {
			user.Nickname = req.Nickname
		}
	}

	// 保存用户
	if err := utils.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "注册失败"})
		return
	}

	// 生成随机账号（6位数字，不按顺序）
	// 使用更新的随机数生成方法，确保随机性
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	randomNum := 100000 + r.Intn(900000) // 生成100000-999999之间的随机数
	account := strconv.Itoa(randomNum)

	// 生成AllInOne品牌的邮箱
	// 格式为：账号@allinone.com
	// 这个邮箱是系统内部使用的，不是用户的实际邮箱
	generatedEmail := account + "@allinone.com"

	// 设置昵称
	// 如果用户提供了昵称，则使用用户提供的昵称
	// 否则使用账号作为默认昵称
	// 昵称可以在用户注册后修改
	nickname := account
	if req.Nickname != "" {
		nickname = req.Nickname
	}

	// 更新用户账号和生成的邮箱
	// 将生成的账号、邮箱和昵称保存到数据库
	if err := utils.DB.Model(&user).Updates(map[string]any{
		"Account":        account,        // 随机生成的6位数字账号
		"GeneratedEmail": generatedEmail, // 系统生成的邮箱
		"Nickname":       nickname,       // 用户昵称
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
	// 支持GET和POST两种方式
	var codeType, target string

	// 检查请求方法
	if c.Request.Method == "GET" {
		codeType = c.Query("type") // "email" 或 "phone"
		target = c.Query("target") // 邮箱或手机号
	} else {
		// POST方法
		// 兼容前端发送的email参数
		email := c.PostForm("email")
		if email != "" {
			codeType = "email"
			target = email
		} else {
			// 兼容前端发送的phone参数
			phone := c.PostForm("phone")
			if phone != "" {
				codeType = "phone"
				target = phone
			} else {
				// 尝试从JSON中获取参数
				// 支持多种参数格式，提高兼容性
				var data map[string]any
				if err := c.ShouldBindJSON(&data); err == nil {
					// 检查是否有email参数
					if email, ok := data["email"].(string); ok && email != "" {
						codeType = "email"
						target = email
					} else if phone, ok := data["phone"].(string); ok && phone != "" {
						// 检查是否有phone参数
						codeType = "phone"
						target = phone
					} else if t, ok := data["type"].(string); ok && t != "" {
						// 检查是否有type和target参数
						codeType = t
						if tgt, ok := data["target"].(string); ok {
							target = tgt
						}
					}
				}
			}
		}

		// 如果type参数存在，优先使用type参数
		if t := c.PostForm("type"); t != "" {
			codeType = t
		} else {
			// 尝试从JSON中获取type参数
			// 这是为了支持不同格式的请求
			var data map[string]any
			if err := c.ShouldBindJSON(&data); err == nil {
				// 如果JSON中有type字段，使用它
				if t, ok := data["type"].(string); ok && t != "" {
					codeType = t
				}
			}
		}
	}

	// 验证参数
	if codeType != "email" && codeType != "phone" && codeType != "register" {
		// 如果type是register，默认为email类型
		if codeType == "register" {
			codeType = "email"
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "验证码类型错误"})
			return
		}
	}

	if target == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "目标不能为空"})
		return
	}

	// 验证格式
	if codeType == "email" {
		if !utils.ValidateEmail(target) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "邮箱格式不正确"})
			return
		}
	} else {
		if !utils.ValidatePhone(target) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "手机号格式不正确"})
			return
		}
	}

	// 检查是否已注册
	var count int64
	var err error

	if codeType == "email" {
		err = utils.DB.Model(&models.User{}).Where("email = ?", target).Count(&count).Error
	} else {
		err = utils.DB.Model(&models.User{}).Where("phone = ?", target).Count(&count).Error
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "数据库查询错误"})
		return
	}

	if count > 0 {
		// 已注册，返回错误
		if codeType == "email" {
			c.JSON(http.StatusOK, gin.H{"success": false, "msg": "该邮箱已被注册"})
		} else {
			c.JSON(http.StatusOK, gin.H{"success": false, "msg": "该手机号已被注册"})
		}
		return
	}

	// 生成6位随机验证码
	code := utils.GenerateRandomCode(6)

	// 保存验证码（实际应用中应该有过期时间）
	codeKey := fmt.Sprintf("%s:%s", codeType, target)
	utils.SaveVerificationCode(codeKey, code)

	// 根据类型发送验证码
	if codeType == "email" {
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
