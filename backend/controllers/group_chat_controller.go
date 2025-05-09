package controllers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"allinone_backend/models"
	"allinone_backend/utils"
)

// GroupChatController 群聊消息控制器
type GroupChatController struct{}

// SendGroupMessage 发送群聊消息
func (g *GroupChatController) SendGroupMessage(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	// 获取当前用户ID
	userIDInterface, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "请先登录",
		})
		return
	}
	
	userID, ok := userIDInterface.(uint)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "用户ID无效",
		})
		return
	}

	// 解析请求参数
	var req struct {
		GroupID        uint     `json:"group_id" binding:"required"`
		Content        string   `json:"content" binding:"required"`
		Type           string   `json:"type" binding:"required"`
		MentionedUsers []uint   `json:"mentioned_users"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 检查用户是否是群成员
	var member models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, userID).First(&member).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "您不是该群组成员",
		})
		return
	}

	// 检查用户是否被禁言
	if member.Muted {
		// 检查禁言是否已过期
		if member.MutedUntil > 0 && member.MutedUntil < time.Now().Unix() {
			// 禁言已过期，解除禁言
			db.Model(&member).Updates(map[string]interface{}{
				"muted":       false,
				"muted_until": 0,
			})
		} else {
			c.JSON(http.StatusForbidden, gin.H{
				"success": false,
				"msg":     "您已被禁言",
			})
			return
		}
	}

	// 创建消息
	message := models.GroupMessage{
		GroupID:   req.GroupID,
		SenderID:  userID,
		Content:   req.Content,
		Type:      req.Type,
		CreatedAt: time.Now().Unix(),
	}

	if err := db.Create(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "发送消息失败: " + err.Error(),
		})
		return
	}

	// 处理@用户
	if len(req.MentionedUsers) > 0 {
		var mentions []models.GroupMessageMention
		for _, mentionedUserID := range req.MentionedUsers {
			mention := models.GroupMessageMention{
				MessageID: message.ID,
				UserID:    mentionedUserID,
				CreatedAt: time.Now().Unix(),
			}
			mentions = append(mentions, mention)
		}

		if len(mentions) > 0 {
			if err := db.Create(&mentions).Error; err != nil {
				utils.Logger.Errorf("创建@记录失败: %v", err)
				// 不影响消息发送，继续执行
			}
		}
	}

	// 更新群成员最后活跃时间
	db.Model(&member).Updates(map[string]interface{}{
		"is_active":   true,
		"last_active": time.Now().Unix(),
	})

	// 获取发送者信息
	var sender models.User
	db.Select("id, nickname, avatar").Where("id = ?", userID).First(&sender)

	// 构建返回数据
	messageData := gin.H{
		"id":         message.ID,
		"group_id":   message.GroupID,
		"sender_id":  message.SenderID,
		"content":    message.Content,
		"type":       message.Type,
		"created_at": message.CreatedAt,
		"sender": gin.H{
			"id":       sender.ID,
			"nickname": sender.Nickname,
			"avatar":   sender.Avatar,
		},
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "发送消息成功",
		"data":    messageData,
	})
}

// GetGroupMessages 获取群聊消息
func (g *GroupChatController) GetGroupMessages(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	// 获取当前用户ID
	userIDInterface, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "请先登录",
		})
		return
	}
	
	userID, ok := userIDInterface.(uint)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "用户ID无效",
		})
		return
	}

	// 获取请求参数
	groupIDStr := c.Query("group_id")
	if groupIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID不能为空",
		})
		return
	}

	groupID, err := strconv.ParseUint(groupIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID格式错误",
		})
		return
	}

	// 检查用户是否是群成员
	var member models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "您不是该群组成员",
		})
		return
	}

	// 获取分页参数
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 100 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// 查询消息
	var messages []models.GroupMessage
	if err := db.Where("group_id = ?", groupID).Order("created_at DESC").Limit(limit).Offset(offset).Find(&messages).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "获取消息失败: " + err.Error(),
		})
		return
	}

	// 获取发送者信息
	var messageDataList []gin.H
	for _, message := range messages {
		var sender models.User
		db.Select("id, nickname, avatar").Where("id = ?", message.SenderID).First(&sender)

		messageData := gin.H{
			"id":         message.ID,
			"group_id":   message.GroupID,
			"sender_id":  message.SenderID,
			"content":    message.Content,
			"type":       message.Type,
			"created_at": message.CreatedAt,
			"sender": gin.H{
				"id":       sender.ID,
				"nickname": sender.Nickname,
				"avatar":   sender.Avatar,
			},
		}

		messageDataList = append(messageDataList, messageData)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取消息成功",
		"data":    messageDataList,
	})
}
