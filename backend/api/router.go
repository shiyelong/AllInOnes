package api

import (
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors"
	"allinone_backend/internal/auth/captcha"

	// 自动引入业务路由
	"allinone_backend/routes"
	"allinone_backend/controllers"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()
	r.Use(cors.Default())

	// 静态文件服务（上传文件可通过 /static/xxx 访问）
	r.Static("/static", "./uploads")

	// 业务路由注册
	r.GET("/api/captcha", captcha.GetCaptcha)
	r.POST("/api/captcha/verify", captcha.VerifyCaptchaHandler)
	routes.RegisterUserRoutes(r)

	routes.RegisterChatRoutes(r)
	routes.RegisterFriendsRoutes(r)
	routes.RegisterHongbaoRoutes(r)
	routes.RegisterWebRTCRoutes(r)
	routes.RegisterGroupRoutes(r)
	r.POST("/upload", controllers.UploadFile)

	return r
}
