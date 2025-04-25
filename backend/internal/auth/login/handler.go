package login

import (
	"net/http"
	"github.com/gin-gonic/gin"
	"allinone_backend/internal/auth/register"
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
	if pwd, ok := register.UserDB[req.Account]; !ok || pwd != req.Password {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "账号或密码错误"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "登录成功"})
}
