package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterTranslationRoutes 注册翻译和语音识别相关路由
func RegisterTranslationRoutes(router *gin.RouterGroup) {
	// 翻译相关
	translationGroup := router.Group("/translation")
	{
		// 翻译文本
		translationGroup.POST("/text", controllers.TranslateText)

		// 获取支持的语言列表
		translationGroup.GET("/languages", controllers.GetSupportedLanguages)

		// 翻译消息
		translationGroup.POST("/message", controllers.TranslateMessage)
	}

	// 语音识别相关
	speechGroup := router.Group("/speech")
	{
		// 语音转文字
		speechGroup.POST("/recognize", controllers.SpeechToText)

		// 发送语音消息并转为文字 - 这个路由已经在speech_routes.go中注册了
		// speechGroup.POST("/send", controllers.SendVoiceMessageWithTranscription)
	}
}
