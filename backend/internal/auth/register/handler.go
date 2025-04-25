package register

import (
	"net/http"
	"github.com/gin-gonic/gin"
	"allinone_backend/internal/auth/captcha"
)

var UserDB = map[string]string{} // 仅示例，实际请用数据库

type RegisterRequest struct {
	Account      string `json:"account"`
	Password     string `json:"password"`
	CaptchaID    string `json:"captcha_id"`
	CaptchaValue string `json:"captcha_value"`
}

func RegisterHandler(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	if !captcha.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "验证码错误"})
		return
	}
	if _, ok := UserDB[req.Account]; ok {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "账号已存在"})
		return
	}
	UserDB[req.Account] = req.Password
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "注册成功"})
}
