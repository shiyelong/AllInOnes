package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterSpeechRoutes 注册语音相关路由
func RegisterSpeechRoutes(r *gin.RouterGroup) {
	speech := r.Group("/speech")
	{
		// 语音转文字 - 这个路由已经在其他地方注册了，所以这里注释掉
		// speech.POST("/recognize", controllers.RecognizeSpeech)

		// 发送语音消息（带转录）
		speech.POST("/send", controllers.SendVoiceMessage)
	}
}
