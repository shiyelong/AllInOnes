package routes

import (
	"allinone_backend/controllers"
	"allinone_backend/internal/auth/login"
	"allinone_backend/internal/auth/register"
	"allinone_backend/internal/auth/sms"

	"github.com/gin-gonic/gin"
)

func RegisterUserRoutes(r *gin.Engine) {
	api := r.Group("/api")
	{
		// 公共API
		api.POST("/register", controllers.Register)                   // 旧的注册接口，保留兼容
		api.POST("/register/new", register.NewRegisterHandler)        // 新的注册接口，支持手机号和邮箱
		api.POST("/register/code", register.GenerateVerificationCode) // 获取验证码（POST方法）
		api.GET("/register/code", register.GenerateVerificationCode)  // 获取验证码（GET方法）
		api.GET("/register/sms", sms.GenerateSMSVerificationHandler)  // 获取短信验证码
		api.POST("/register/check", register.CheckExistsHandler)      // 检查邮箱/手机号是否已注册
		api.POST("/login", controllers.Login)                         // 旧的登录接口，保留兼容
		api.POST("/login/new", login.NewLoginHandler)                 // 新的登录接口，支持账号、手机号和邮箱
		api.POST("/validate-token", controllers.ValidateToken)        // 验证token接口

		// 用户相关API
		user := api.Group("/user")
		{
			user.POST("/register", controllers.RegisterUser)
			user.GET("/get_by_account", controllers.GetUserByAccount)

			// 需要认证的API
			authUser := user.Group("")
			authUser.Use(controllers.AuthMiddleware())
			{
				// 用户信息已在主路由中注册，这里不再重复注册
				// authUser.GET("/info", controllers.GetUserInfo)
				// authUser.PUT("/info", controllers.UpdateUserInfo)

				// 头像和昵称
				authUser.POST("/avatar", controllers.UploadAvatar)
				authUser.POST("/avatar/file", controllers.UploadAvatarFile)
				authUser.PUT("/nickname", controllers.UpdateNickname)
			}

			// 公开的用户信息API
			user.GET("/avatar/:id", controllers.GetUserAvatar)
		}
	}
}
