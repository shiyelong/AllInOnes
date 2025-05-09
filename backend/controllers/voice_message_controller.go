package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// 上传语音消息
func UploadVoiceMessage(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 获取接收者ID
	receiverIDStr := c.PostForm("receiver_id")
	if receiverIDStr == "" {
		utils.Logger.Errorf("接收者ID为空")
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "接收者ID不能为空"})
		return
	}

	receiverID, err := strconv.ParseUint(receiverIDStr, 10, 64)
	if err != nil {
		utils.Logger.Errorf("接收者ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "接收者ID无效"})
		return
	}

	// 获取语音时长
	durationStr := c.PostForm("duration")
	if durationStr == "" {
		utils.Logger.Errorf("语音时长为空")
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "语音时长不能为空"})
		return
	}

	duration, err := strconv.Atoi(durationStr)
	if err != nil {
		utils.Logger.Errorf("语音时长无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "语音时长无效"})
		return
	}

	// 获取语音文件
	file, err := c.FormFile("voice")
	if err != nil {
		utils.Logger.Errorf("获取语音文件失败: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "获取语音文件失败"})
		return
	}

	// 检查文件类型
	if !isValidAudioFile(file.Filename) {
		utils.Logger.Errorf("文件类型不支持: %s", file.Filename)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "只支持m4a、mp3、wav、aac格式的语音文件"})
		return
	}

	// 创建上传目录
	uploadDir := "uploads/voice"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		utils.Logger.Errorf("创建上传目录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建上传目录失败"})
		return
	}

	// 生成唯一文件名
	fileExt := filepath.Ext(file.Filename)
	fileName := fmt.Sprintf("%s%s", uuid.New().String(), fileExt)
	filePath := filepath.Join(uploadDir, fileName)

	// 保存文件
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		utils.Logger.Errorf("保存语音文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "保存语音文件失败"})
		return
	}

	// 生成可访问的URL
	fileURL := fmt.Sprintf("/uploads/voice/%s", fileName)

	// 获取数据库连接
	db := c.MustGet("db").(*gorm.DB)

	// 创建语音消息记录
	now := time.Now().Unix()
	voiceMessage := models.VoiceMessage{
		SenderID:   userID,
		ReceiverID: uint(receiverID),
		FilePath:   filePath,
		URL:        fileURL,
		Duration:   duration,
		Status:     1, // 已发送
		CreatedAt:  now,
	}

	if err := db.Create(&voiceMessage).Error; err != nil {
		utils.Logger.Errorf("创建语音消息记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建语音消息记录失败"})
		return
	}

	// 创建聊天消息记录
	chatMessage := models.ChatMessage{
		SenderID:   userID,
		ReceiverID: uint(receiverID),
		Content:    fileURL,
		Type:       "voice",
		Extra:      fmt.Sprintf(`{"duration":%d,"url":"%s"}`, duration, fileURL),
		Status:     1, // 已发送
		CreatedAt:  now,
	}

	if err := db.Create(&chatMessage).Error; err != nil {
		utils.Logger.Errorf("创建聊天消息记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建聊天消息记录失败"})
		return
	}

	// 发送WebSocket消息通知接收者
	message := map[string]interface{}{
		"type":       "new_message",
		"message_id": chatMessage.ID,
		"sender_id":  userID,
		"content":    fileURL,
		"msg_type":   "voice",
		"extra":      fmt.Sprintf(`{"duration":%d,"url":"%s"}`, duration, fileURL),
		"timestamp":  now,
	}

	// 使用WebSocket服务器发送消息
	utils.WebRTCServer.SendToUser(uint(receiverID), []byte(fmt.Sprintf("%v", message)))

	utils.Logger.Infof("上传语音消息成功: senderID=%d, receiverID=%d, messageID=%d, duration=%d",
		userID, receiverID, chatMessage.ID, duration)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "上传语音消息成功",
		"data": gin.H{
			"id":       chatMessage.ID,
			"url":      fileURL,
			"duration": duration,
		},
	})
}

// 获取语音消息
func GetVoiceMessage(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 获取消息ID
	messageID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("消息ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "消息ID无效"})
		return
	}

	// 获取数据库连接
	db := c.MustGet("db").(*gorm.DB)

	// 查询聊天消息
	var chatMessage models.ChatMessage
	if err := db.Where("id = ? AND type = 'voice' AND (sender_id = ? OR receiver_id = ?)",
		messageID, userID, userID).First(&chatMessage).Error; err != nil {
		utils.Logger.Errorf("查询语音消息失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "语音消息不存在"})
		return
	}

	utils.Logger.Infof("获取语音消息成功: userID=%d, messageID=%d", userID, messageID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取语音消息成功",
		"data": gin.H{
			"id":       chatMessage.ID,
			"url":      chatMessage.Content,
			"duration": extractDurationFromExtra(chatMessage.Extra),
		},
	})
}

// 从Extra字段中提取语音时长
func extractDurationFromExtra(extra string) int {
	// 简单实现，实际应该使用JSON解析
	var duration int
	fmt.Sscanf(extra, `{"duration":%d`, &duration)
	return duration
}

// 检查文件是否为有效的音频文件
func isValidAudioFile(filename string) bool {
	ext := filepath.Ext(filename)
	validExts := map[string]bool{
		".m4a": true,
		".mp3": true,
		".wav": true,
		".aac": true,
	}
	return validExts[ext]
}

// 下载语音文件
func DownloadVoiceFile(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 获取文件名
	fileName := c.Param("filename")
	if fileName == "" {
		utils.Logger.Errorf("文件名为空")
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "文件名不能为空"})
		return
	}

	// 构建文件路径
	filePath := filepath.Join("uploads/voice", fileName)

	// 检查文件是否存在
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		utils.Logger.Errorf("语音文件不存在: %s", filePath)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "语音文件不存在"})
		return
	}

	// 打开文件
	file, err := os.Open(filePath)
	if err != nil {
		utils.Logger.Errorf("打开语音文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "打开语音文件失败"})
		return
	}
	defer file.Close()

	// 获取文件信息
	fileInfo, err := file.Stat()
	if err != nil {
		utils.Logger.Errorf("获取语音文件信息失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "获取语音文件信息失败"})
		return
	}

	// 设置响应头
	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", fileName))
	c.Header("Content-Type", "application/octet-stream")
	c.Header("Content-Length", fmt.Sprintf("%d", fileInfo.Size()))

	// 发送文件
	c.File(filePath)

	utils.Logger.Infof("下载语音文件成功: userID=%d, fileName=%s", userID, fileName)
}
