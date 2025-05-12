package api

import (
	"allinone_backend/internal/auth/captcha"
	"allinone_backend/middleware"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	// 自动引入业务路由
	"allinone_backend/controllers"
	"allinone_backend/routes"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()

	// 配置CORS
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Authorization"}
	r.Use(cors.New(config))

	// 静态文件服务（上传文件可通过 /uploads/xxx 访问）
	r.Static("/uploads", "./uploads")

	// 保留旧的静态文件路径，兼容旧代码
	r.Static("/static", "./uploads")

	// 注册用户路由（包含登录注册等公共API）
	routes.RegisterUserRoutes(r)

	// 注册新的用户路由已合并到RegisterUserRoutes

	// API分组
	api := r.Group("/api")

	// 无需认证的公共API
	{
		// 健康检查API - 用于监控和部署检查
		api.GET("/health", controllers.HealthCheck)

		// 验证码相关
		api.GET("/captcha", captcha.GetCaptcha)
		api.POST("/captcha/verify", captcha.VerifyCaptchaHandler)

		// 文件上传
		api.POST("/upload", controllers.UploadFileEnhanced)
	}

	// 需要认证的API
	auth := api.Group("/")
	auth.Use(middleware.JWTAuth())
	{
		// 用户相关
		auth.GET("/user/info", controllers.GetUserInfo)
		auth.PUT("/user/info", controllers.UpdateUserInfo)

		// 聊天相关
		routes.RegisterChatRoutes(auth)

		// 好友相关
		routes.RegisterFriendsRoutes(auth)

		// 视频通话相关
		routes.RegisterWebRTCRoutes(auth)

		// 群组相关
		routes.RegisterGroupRoutes(auth)

		// 朋友圈相关
		routes.RegisterMomentsRoutes(auth)

		// 钱包相关
		routes.RegisterWalletRoutesNew(auth)

		// 红包相关
		routes.RegisterRedPacketRoutes(auth)

		// 翻译相关
		routes.RegisterTranslationRoutes(auth)

		// 语音识别相关
		routes.RegisterSpeechRoutes(auth)

		// AI相关
		routes.RegisterAIRoutes(auth)

		// WebSocket相关
		routes.RegisterWebSocketRoutes(auth)

		// 语音和视频通话相关
		routes.SetupCallRoutes(r)

		// 语音消息相关
		routes.RegisterVoiceMessageRoutes(auth)

		// 核心功能保留，移除非核心功能
	}

	return r
}
