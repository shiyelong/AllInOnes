package controllers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// 退出登录
func Logout(c *gin.Context) {
	// 前端只需清除本地token/session即可，后端可返回成功
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "退出登录成功",
	})
}
