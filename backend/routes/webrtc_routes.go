package routes

import (
	"allinone_backend/controllers"
	"github.com/gin-gonic/gin"
)

func RegisterWebRTCRoutes(r *gin.Engine) {
	r.POST("/webrtc/signal", controllers.WebRTCSignal)
}
