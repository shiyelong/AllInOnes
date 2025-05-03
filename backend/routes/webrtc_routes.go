package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterWebRTCRoutes(r *gin.RouterGroup) {
	webrtc := r.Group("/webrtc")
	{
		webrtc.POST("/signal", controllers.WebRTCSignal)
	}
}
