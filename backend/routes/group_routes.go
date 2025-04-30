package routes

import (
	"github.com/gin-gonic/gin"
	"allinone_backend/controllers"
)

func RegisterGroupRoutes(r *gin.Engine) {
	r.POST("/group/create", controllers.CreateGroup)
}
