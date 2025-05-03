package captcha

import (
	"allinone_backend/utils"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mojocn/base64Captcha"
)

// 定义验证码存储
var store = base64Captcha.DefaultMemStore

// GetCaptcha 获取验证码
func GetCaptcha(c *gin.Context) {
	// 在测试环境中，我们使用一个随机的数学表达式或字母数字组合
	if c.Query("test") == "1" || true { // 始终使用测试模式
		// 生成一个随机的验证码ID
		id := "captcha_id_" + time.Now().Format("20060102150405")

		// 生成随机验证码（数学表达式或字母数字组合）
		var captchaValue string
		var captchaDisplay string

		// 使用更新的随机数生成方法
		r := rand.New(rand.NewSource(time.Now().UnixNano()))

		// 随机决定使用数学表达式或字母数字组合
		if r.Intn(2) == 0 {
			// 生成简单的数学表达式
			a := r.Intn(10) + 1
			b := r.Intn(10) + 1
			op := []string{"+", "-", "×"}[r.Intn(3)]

			captchaDisplay = fmt.Sprintf("%d %s %d = ?", a, op, b)

			// 计算结果
			var result int
			switch op {
			case "+":
				result = a + b
			case "-":
				result = a - b
			case "×":
				result = a * b
			}

			captchaValue = fmt.Sprintf("%d", result)
		} else {
			// 生成字母数字组合
			chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
			length := 4
			captchaValue = ""
			for i := 0; i < length; i++ {
				captchaValue += string(chars[r.Intn(len(chars))])
			}
			captchaDisplay = captchaValue
		}

		// 将验证码保存到自定义存储中
		utils.SaveCaptcha(id, captchaValue)

		// 生成一个简单的验证码图片（使用一个1x1像素的透明图片）
		b64s := "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"

		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"data": gin.H{
				"captcha_id":    id,
				"captcha_image": b64s,
				"captcha_text":  captchaDisplay, // 添加验证码文本，用于前端显示
			},
		})
		return
	}

	// 以下是正常的验证码生成逻辑
	// 生成验证码配置
	driver := base64Captcha.NewDriverDigit(80, 240, 5, 0.7, 80)
	captcha := base64Captcha.NewCaptcha(driver, store)

	// 生成验证码
	id, b64s, _, err := captcha.Generate()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "生成验证码失败",
		})
		return
	}

	// 将验证码保存到自定义存储中
	utils.SaveCaptcha(id, store.Get(id, true))

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"captcha_id":    id,
			"captcha_image": b64s,
		},
	})
}

// VerifyCaptchaHandler 验证验证码
func VerifyCaptchaHandler(c *gin.Context) {
	var req struct {
		CaptchaID    string `json:"captcha_id" binding:"required"`
		CaptchaValue string `json:"captcha_value" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 验证验证码
	if utils.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"msg":     "验证码正确",
		})
	} else {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "验证码错误或已过期",
		})
	}
}

// 定期清理过期验证码
func init() {
	go func() {
		ticker := time.NewTicker(10 * time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			utils.CleanExpiredCaptcha()
		}
	}()
}
