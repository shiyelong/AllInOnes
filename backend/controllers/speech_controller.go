package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/base64"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
)

// RecognizeSpeech 将语音转换为文本
func RecognizeSpeech(c *gin.Context) {
	// 获取用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "未授权",
		})
		return
	}

	// 解析请求
	var req struct {
		AudioData string `json:"audio_data"` // base64编码的音频数据
		Format    string `json:"format"`     // 音频格式，如wav, mp3等
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 检查音频数据
	if req.AudioData == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "音频数据不能为空",
		})
		return
	}

	// 解码base64音频数据
	audioBytes, err := base64.StdEncoding.DecodeString(req.AudioData)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "音频数据解码失败",
		})
		return
	}

	// 创建临时文件保存音频
	tempDir := os.TempDir()
	audioFileName := fmt.Sprintf("speech_%d_%d.%s", userID, time.Now().UnixNano(), req.Format)
	audioFilePath := filepath.Join(tempDir, audioFileName)

	// 写入临时文件
	if err := os.WriteFile(audioFilePath, audioBytes, 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "保存音频文件失败",
		})
		return
	}
	defer os.Remove(audioFilePath) // 处理完后删除临时文件

	// 调用语音识别服务
	text, err := utils.SpeechToText(audioFilePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "语音识别失败: " + err.Error(),
		})
		return
	}

	// 返回识别结果
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"text": text,
		},
	})
}

// SendVoiceMessage 发送语音消息并附带转录文本
func SendVoiceMessage(c *gin.Context) {
	// 获取用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "未授权",
		})
		return
	}

	// 解析请求
	var req struct {
		ToID      uint   `json:"to_id"`      // 接收者ID
		AudioData string `json:"audio_data"` // base64编码的音频数据
		Format    string `json:"format"`     // 音频格式，如wav, mp3等
		Duration  int    `json:"duration"`   // 音频时长（秒）
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 检查参数
	if req.ToID == 0 || req.AudioData == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "接收者ID和音频数据不能为空",
		})
		return
	}

	// 解码base64音频数据
	audioBytes, err := base64.StdEncoding.DecodeString(req.AudioData)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "音频数据解码失败",
		})
		return
	}

	// 创建临时文件保存音频
	tempDir := os.TempDir()
	audioFileName := fmt.Sprintf("voice_msg_%d_%d.%s", userID, time.Now().UnixNano(), req.Format)
	audioFilePath := filepath.Join(tempDir, audioFileName)

	// 写入临时文件
	if err := os.WriteFile(audioFilePath, audioBytes, 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "保存音频文件失败",
		})
		return
	}
	defer os.Remove(audioFilePath) // 处理完后删除临时文件

	// 调用语音识别服务
	text, err := utils.SpeechToText(audioFilePath)
	if err != nil {
		// 即使语音识别失败，我们仍然可以发送语音消息，只是没有转录文本
		text = "[语音识别失败]"
	}

	// 保存音频文件到服务器
	uid := userID.(uint)
	uploadDir := "static/uploads/voice"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "创建上传目录失败",
		})
		return
	}

	// 生成唯一文件名
	timestamp := time.Now().Unix()
	savedFileName := fmt.Sprintf("voice_%d_%d_%d.%s", uid, req.ToID, timestamp, req.Format)
	savedFilePath := filepath.Join(uploadDir, savedFileName)

	// 复制临时文件到上传目录
	if err := os.WriteFile(savedFilePath, audioBytes, 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "保存音频文件失败",
		})
		return
	}

	// 构建音频URL
	audioURL := fmt.Sprintf("/static/uploads/voice/%s", savedFileName)

	// 创建消息
	message := models.ChatMessage{
		SenderID:   uid,
		ReceiverID: req.ToID,
		Content:    audioURL,
		Type:       "voice",
		CreatedAt:  timestamp,
		Extra:      fmt.Sprintf(`{"duration":%d,"text":"%s"}`, req.Duration, text),
	}

	// 保存消息到数据库
	if err := utils.DB.Create(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "保存消息失败: " + err.Error(),
		})
		return
	}

	// 返回成功响应
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"message_id": message.ID,
			"audio_url":  audioURL,
			"text":       text,
			"created_at": timestamp,
		},
	})
}
