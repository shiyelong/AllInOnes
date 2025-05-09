package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 清除用户所有聊天记录
func ClearAllUserMessages(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "未授权",
		})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 使用事务确保数据一致性
	err := db.Transaction(func(tx *gorm.DB) error {
		// 1. 查找用户相关的所有消息
		var messages []models.ChatMessage
		if err := tx.Where("sender_id = ? OR receiver_id = ?", userID, userID).Find(&messages).Error; err != nil {
			return err
		}

		// 2. 删除相关的媒体文件
		for _, msg := range messages {
			if msg.Type == "image" || msg.Type == "video" || msg.Type == "file" {
				// 从Extra字段中提取文件路径
				// 注意：实际实现需要根据你的文件存储方式调整
				if msg.Extra != "" {
					// 这里假设Extra中包含了文件路径信息
					// 实际情况可能需要解析JSON等
					filePath := filepath.Join(utils.GetUploadDir(), msg.Content)
					if _, err := os.Stat(filePath); err == nil {
						os.Remove(filePath)
					}
				}
			}
		}

		// 3. 删除消息记录
		if err := tx.Where("sender_id = ? OR receiver_id = ?", userID, userID).Delete(&models.ChatMessage{}).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "清除聊天记录失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "所有聊天记录已清除",
	})
}

// 清除特定聊天的消息记录
func ClearChatMessages(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "未授权",
		})
		return
	}

	var req struct {
		TargetID uint `json:"target_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误",
		})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 使用事务确保数据一致性
	err := db.Transaction(func(tx *gorm.DB) error {
		// 1. 查找相关的所有消息
		var messages []models.ChatMessage
		if err := tx.Where(
			"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
			userID, req.TargetID, req.TargetID, userID,
		).Find(&messages).Error; err != nil {
			return err
		}

		// 2. 删除相关的媒体文件
		for _, msg := range messages {
			if msg.Type == "image" || msg.Type == "video" || msg.Type == "file" {
				// 从Extra字段中提取文件路径
				if msg.Extra != "" {
					filePath := filepath.Join(utils.GetUploadDir(), msg.Content)
					if _, err := os.Stat(filePath); err == nil {
						os.Remove(filePath)
					}
				}
			}
		}

		// 3. 删除消息记录
		if err := tx.Where(
			"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
			userID, req.TargetID, req.TargetID, userID,
		).Delete(&models.ChatMessage{}).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "清除聊天记录失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "聊天记录已清除",
	})
}
