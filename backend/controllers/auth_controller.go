package controllers

import (
	"github.com/gin-gonic/gin"
)


// 登录
func Login(c *gin.Context) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	// TODO: 校验用户名密码，生成token
	token := "mock-token" // 实际应生成JWT等
	c.JSON(200, gin.H{"success": true, "msg": "登录成功", "token": token})
}
// 退出登录
func Logout(c *gin.Context) {
	// 前端只需清除本地token/session即可，后端可返回成功
	c.JSON(200, gin.H{"success": true, "msg": "退出登录成功"})
}
