package routes

import (
	"github.com/gin-gonic/gin"
	"allinone_backend/controllers"
)

func RegisterUserRoutes(r *gin.Engine) {
	user := r.Group("/user")
	{
		user.POST("/register", controllers.RegisterUser)
		user.GET("/get_by_account", controllers.GetUserByAccount)
	}
}
