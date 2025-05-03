package routes

import (
	"allinone_backend/controllers"
	"allinone_backend/middleware"

	"github.com/gin-gonic/gin"
)

// 设置语音和视频通话相关路由
func SetupCallRoutes(router *gin.Engine) {
	// 语音和视频通话相关路由
	callGroup := router.Group("/api/call")
	callGroup.Use(middleware.JWTAuth())

	// 语音通话相关
	voice := callGroup.Group("/voice")
	{
		voice.GET("/records", controllers.GetVoiceCallRecords)
		voice.GET("/records/:id", controllers.GetVoiceCallDetail)
		voice.POST("/initiate", controllers.InitiateVoiceCall)
		voice.POST("/accept", controllers.HandleAcceptVoiceCall)
		voice.POST("/reject", controllers.HandleRejectVoiceCall)
		voice.POST("/end", controllers.HandleEndVoiceCall)
		voice.GET("/stats", controllers.GetVoiceCallStats)
	}

	// 视频通话相关
	video := callGroup.Group("/video")
	{
		video.GET("/records", controllers.GetVideoCallRecords)
		video.GET("/records/:id", controllers.GetVideoCallDetail)
		video.POST("/initiate", controllers.InitiateVideoCall)
		video.POST("/accept", controllers.HandleAcceptVideoCall)
		video.POST("/reject", controllers.HandleRejectVideoCall)
		video.POST("/end", controllers.HandleEndVideoCall)
		video.GET("/stats", controllers.GetVideoCallStats)
	}
}
