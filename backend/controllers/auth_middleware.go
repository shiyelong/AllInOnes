package controllers

import (
	"allinone_backend/utils"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// AuthMiddleware 认证中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取Authorization头
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"msg":     "未提供token",
			})
			c.Abort()
			return
		}

		// 检查Bearer前缀
		if !strings.HasPrefix(authHeader, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"msg":     "无效的token格式",
			})
			c.Abort()
			return
		}

		// 提取token
		token := authHeader[7:] // 去掉"Bearer "前缀

		// 解析token
		claims, err := utils.ParseToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"msg":     "token无效或已过期",
			})
			c.Abort()
			return
		}

		// 将用户ID和账号存储在上下文中
		c.Set("user_id", claims.UserID)
		c.Set("account", claims.Account)

		c.Next()
	}
}
