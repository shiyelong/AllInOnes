package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterChatRoutes(r *gin.Engine) {
	chat := r.Group("/chat")
	{
		chat.POST("/single", controllers.SingleChat)
		chat.POST("/group", controllers.GroupChat)
	}
}
