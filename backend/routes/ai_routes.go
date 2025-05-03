package routes

import (
	"github.com/gin-gonic/gin"
)

// RegisterAIRoutes 注册AI助手相关路由
func RegisterAIRoutes(r *gin.RouterGroup) {
	ai := r.Group("/ai")
	{
		// 获取AI助手回复
		ai.POST("/chat", func(c *gin.Context) {
			var req struct {
				Message string `json:"message" binding:"required"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(400, gin.H{
					"success": false,
					"msg":     "请求参数错误",
				})
				return
			}

			// 简单的AI回复逻辑
			response := "您好，我是AI助手。您的问题是：" + req.Message
			
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取AI回复成功",
				"data": gin.H{
					"response": response,
				},
			})
		})
	}
}
