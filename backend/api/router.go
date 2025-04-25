package api

import (
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors"
	"allinone_backend/internal/auth/captcha"
	"allinone_backend/internal/auth/register"
	"allinone_backend/internal/auth/login"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()
	r.Use(cors.Default())
	r.GET("/api/captcha", captcha.GetCaptcha)
	r.POST("/api/captcha/verify", captcha.VerifyCaptchaHandler)
	r.POST("/api/register", register.RegisterHandler)
	r.POST("/api/login", login.LoginHandler)
	return r
}
