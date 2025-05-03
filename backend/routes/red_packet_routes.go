package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterRedPacketRoutes 注册红包相关路由
func RegisterRedPacketRoutes(r *gin.RouterGroup) {
	redPacket := r.Group("/red-packet")
	{
		// 创建红包
		redPacket.POST("", controllers.CreateRedPacket)
		
		// 领取红包
		redPacket.POST("/receive", controllers.ReceiveRedPacket)
		
		// 获取红包详情
		redPacket.GET("/:id", controllers.GetRedPacketDetail)
	}
}
