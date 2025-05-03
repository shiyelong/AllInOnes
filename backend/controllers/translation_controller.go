package controllers

import (
	"net/http"
	"time"

	"allinone_backend/models"
	"allinone_backend/utils"

	"github.com/gin-gonic/gin"
)

// 翻译文本
func TranslateText(c *gin.Context) {
	// 获取当前用户
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		Text       string `json:"text" binding:"required"`
		SourceLang string `json:"source_lang"`
		TargetLang string `json:"target_lang" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 如果未指定源语言，则自动检测
	sourceLang := req.SourceLang
	if sourceLang == "" || sourceLang == "auto" {
		detectedLang, err := utils.DetectLanguage(req.Text)
		if err != nil {
			// 尝试备用方法
			detectedLang, err = utils.DetectLanguageWithGoogle(req.Text)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "语言检测失败"})
				return
			}
		}
		sourceLang = detectedLang
	}

	// 翻译文本
	translatedText, err := utils.TranslateText(req.Text, sourceLang, req.TargetLang)
	if err != nil {
		// 尝试备用翻译方法
		translatedText, err = utils.TranslateTextWithGoogle(req.Text, sourceLang, req.TargetLang)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "翻译失败"})
			return
		}
	}

	// 返回翻译结果
	c.JSON(http.StatusOK, gin.H{
		"original_text":   req.Text,
		"translated_text": translatedText,
		"source_lang":     sourceLang,
		"target_lang":     req.TargetLang,
	})
}

// 获取支持的语言列表
func GetSupportedLanguages(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"languages": utils.SupportedLanguages,
	})
}

// 语音转文字
func SpeechToText(c *gin.Context) {
	// 获取当前用户
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		AudioBase64 string `json:"audio_base64" binding:"required"`
		Language    string `json:"language"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 语音转文字
	text, err := utils.TranscribeSpeechFromBase64(req.AudioBase64, req.Language)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "语音识别失败"})
		return
	}

	// 返回识别结果
	c.JSON(http.StatusOK, gin.H{
		"text":     text,
		"language": req.Language,
	})
}

// 发送语音消息并转为文字
func SendVoiceMessageWithTranscription(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		ReceiverID  uint   `json:"receiver_id"`
		GroupID     uint   `json:"group_id"`
		AudioBase64 string `json:"audio_base64" binding:"required"`
		Language    string `json:"language"`
		Duration    int    `json:"duration"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 检查接收者
	if req.ReceiverID == 0 && req.GroupID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "必须指定接收者ID或群组ID"})
		return
	}

	// 语音转文字
	text, err := utils.TranscribeSpeechFromBase64(req.AudioBase64, req.Language)
	if err != nil {
		// 如果语音识别失败，仍然发送语音消息，但不包含文字
		text = ""
	}

	// 创建语音消息
	message := models.ChatMessage{
		SenderID:   userID.(uint),
		ReceiverID: req.ReceiverID,
		GroupID:    req.GroupID,
		Content:    req.AudioBase64,
		Type:       "voice",
		Extra:      `{"duration":` + string(rune(req.Duration)) + `,"text":"` + text + `"}`,
		Status:     1,
		CreatedAt:  time.Now().Unix(),
	}

	// 保存消息
	if err := utils.DB.Create(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "发送消息失败"})
		return
	}

	// 返回消息和转录文本
	c.JSON(http.StatusOK, gin.H{
		"message": message,
		"text":    text,
	})
}

// 翻译消息
func TranslateMessage(c *gin.Context) {
	// 获取当前用户
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		MessageID  uint   `json:"message_id" binding:"required"`
		TargetLang string `json:"target_lang" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 获取消息
	var message models.ChatMessage
	if err := utils.DB.First(&message, req.MessageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "消息不存在"})
		return
	}

	// 检查消息类型
	if message.Type != "text" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "只能翻译文本消息"})
		return
	}

	// 检查是否已经翻译过
	if message.TranslatedText != "" && message.TargetLanguage == req.TargetLang {
		// 已经翻译过，直接返回
		c.JSON(http.StatusOK, gin.H{
			"message_id":      message.ID,
			"original_text":   message.Content,
			"translated_text": message.TranslatedText,
			"source_lang":     message.SourceLanguage,
			"target_lang":     message.TargetLanguage,
		})
		return
	}

	// 检测源语言
	sourceLang := message.SourceLanguage
	if sourceLang == "" {
		detectedLang, err := utils.DetectLanguage(message.Content)
		if err != nil {
			// 尝试备用方法
			detectedLang, err = utils.DetectLanguageWithGoogle(message.Content)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "语言检测失败"})
				return
			}
		}
		sourceLang = detectedLang
	}

	// 翻译文本
	translatedText, err := utils.TranslateText(message.Content, sourceLang, req.TargetLang)
	if err != nil {
		// 尝试备用翻译方法
		translatedText, err = utils.TranslateTextWithGoogle(message.Content, sourceLang, req.TargetLang)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "翻译失败"})
			return
		}
	}

	// 更新消息
	message.TranslatedText = translatedText
	message.SourceLanguage = sourceLang
	message.TargetLanguage = req.TargetLang

	if err := utils.DB.Save(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存翻译结果失败"})
		return
	}

	// 返回翻译结果
	c.JSON(http.StatusOK, gin.H{
		"message_id":      message.ID,
		"original_text":   message.Content,
		"translated_text": translatedText,
		"source_lang":     sourceLang,
		"target_lang":     req.TargetLang,
	})
}
