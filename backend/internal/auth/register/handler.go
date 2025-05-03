package register

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

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
	if !utils.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "验证码错误"})
		return
	}
	// 检查账号是否已存在
	var count int64
	err := utils.DB.Model(&models.User{}).Where("account = ?", req.Account).Count(&count).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "数据库错误"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "账号已存在"})
		return
	}
	hashedPwd, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "密码加密失败"})
		return
	}
	user := models.User{
		Account:   req.Account,
		Password:  string(hashedPwd),
		CreatedAt: time.Now().Unix(),
	}
	if err := utils.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "注册失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "注册成功"})
}
