package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterGroupRoutes(r *gin.RouterGroup) {
	group := r.Group("/group")
	{
		group.POST("/create", controllers.CreateGroup)
	}
}
