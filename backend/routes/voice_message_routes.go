package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// 注册语音消息相关路由
func RegisterVoiceMessageRoutes(r *gin.RouterGroup) {
	voice := r.Group("/message/voice")
	{
		// 上传语音消息
		voice.POST("", controllers.UploadVoiceMessage)
		
		// 获取语音消息
		voice.GET("/:id", controllers.GetVoiceMessage)
		
		// 下载语音文件
		voice.GET("/download/:filename", controllers.DownloadVoiceFile)
	}
}
