package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterAIRoutes 注册AI助手相关路由
func RegisterAIRoutes(r *gin.RouterGroup) {
	ai := r.Group("/ai")
	{
		// AI工具列表
		ai.GET("/tools", controllers.ListAiTools)

		// AI聊天历史
		ai.GET("/history", controllers.GetAIChatHistory)

		// AI设置
		ai.GET("/settings", controllers.GetAISettings)
		ai.PUT("/settings", controllers.UpdateAISettings)

		// 个人AI助手
		ai.POST("/personal/chat", controllers.ChatWithPersonalAI)

		// 群组AI管理
		ai.POST("/group/chat", controllers.ChatWithGroupAI)

		// 游戏AI陪玩
		ai.POST("/game/chat", controllers.ChatWithGameAI)
	}
}
