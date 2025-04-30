package routes

import (
	"allinone_backend/controllers"
	"github.com/gin-gonic/gin"
)

func RegisterHongbaoRoutes(r *gin.Engine) {
	r.POST("/hongbao/send", controllers.SendHongbao)
}
