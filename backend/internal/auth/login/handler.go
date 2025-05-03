package login

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type LoginRequest struct {
	Account  string `json:"account"`
	Password string `json:"password"`
}

func LoginHandler(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	var user models.User
	err := utils.DB.Where("account = ?", req.Account).First(&user).Error
	if err != nil || bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "账号或密码错误"})
		return
	}
	// 临时使用固定的用户ID
	token, err := utils.GenerateToken(1, req.Account)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "生成token失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "登录成功", "token": token})
}
