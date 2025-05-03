package routes

import (
	"allinone_backend/controllers"
	"allinone_backend/internal/auth/login"
	"allinone_backend/internal/auth/register"

	"github.com/gin-gonic/gin"
)

func RegisterNewUserRoutes(r *gin.Engine) {
	api := r.Group("/api")
	{
		// 公共API
		api.POST("/register", controllers.Register)                   // 旧的注册接口，保留兼容
		api.POST("/register/new", register.NewRegisterHandler)        // 新的注册接口，支持手机号和邮箱
		api.POST("/register/code", register.GenerateVerificationCode) // 获取验证码
		api.POST("/login", controllers.Login)                         // 旧的登录接口，保留兼容
		api.POST("/login/new", login.NewLoginHandler)                 // 新的登录接口，支持手机号和邮箱

		// 用户相关API
		user := api.Group("/user")
		{
			user.POST("/register", controllers.RegisterUser)
			user.GET("/get_by_account", controllers.GetUserByAccount)
		}
	}
}
