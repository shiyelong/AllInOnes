package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterWebRTCRoutes(r *gin.RouterGroup) {
	webrtc := r.Group("/webrtc")
	{
		// WebRTC信令
		webrtc.POST("/signal", controllers.WebRTCSignal)

		// 视频通话
		webrtc.POST("/video/start", controllers.StartVideoCallWebRTC)
		webrtc.POST("/video/end", controllers.EndVideoCallWebRTC)
		webrtc.POST("/video/reject", controllers.RejectVideoCallWebRTC)

		// 语音通话
		webrtc.POST("/voice/start", controllers.StartVoiceCallWebRTC)
		webrtc.POST("/voice/end", controllers.EndVoiceCallWebRTC)
		webrtc.POST("/voice/reject", controllers.RejectVoiceCallWebRTC)

		// 通话历史
		webrtc.GET("/history", controllers.GetCallHistoryWebRTC)
	}
}
