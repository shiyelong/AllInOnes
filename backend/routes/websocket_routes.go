package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterWebSocketRoutes 注册WebSocket相关路由
func RegisterWebSocketRoutes(r *gin.RouterGroup) {
	ws := r.Group("/ws")
	{
		// WebSocket连接
		ws.GET("", controllers.HandleWebSocket)
	}
}
