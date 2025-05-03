package controllers

import (
	"allinone_backend/models"
	"allinone_backend/repositories"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 发送消息
func SendMessage(c *gin.Context) {
	// 解析请求参数
	var req struct {
		FromID  string `json:"from_id"`
		ToID    string `json:"to_id"`
		Content string `json:"content"`
		Type    string `json:"type"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 转换ID
	fromID, err := strconv.ParseUint(req.FromID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的发送者ID"})
		return
	}

	toID, err := strconv.ParseUint(req.ToID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的接收者ID"})
		return
	}

	// 创建消息
	message := models.ChatMessage{
		SenderID:   uint(fromID),
		ReceiverID: uint(toID),
		Content:    req.Content,
		Type:       req.Type,
		CreatedAt:  time.Now().Unix(),
	}

	// 保存消息
	db := c.MustGet("db").(*gorm.DB)
	if err := db.Create(&message).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "消息保存失败"})
		return
	}

	// TODO: WebSocket 推送实时消息

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "发送成功",
		"data": gin.H{
			"id":         message.ID,
			"from_id":    message.SenderID,
			"to_id":      message.ReceiverID,
			"content":    message.Content,
			"type":       message.Type,
			"created_at": message.CreatedAt,
		},
	})
}

// 拉取历史消息
func GetMessagesByUser(c *gin.Context) {
	userIDStr := c.Query("user_id")
	targetIDStr := c.Query("target_id")

	if userIDStr == "" || targetIDStr == "" {
		c.JSON(400, gin.H{"success": false, "msg": "缺少必要参数"})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的user_id参数"})
		return
	}

	targetID, err := strconv.ParseUint(targetIDStr, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的target_id参数"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 查询两个用户之间的所有消息
	var messages []models.ChatMessage
	if err := db.Where(
		"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
		userID, targetID, targetID, userID,
	).Order("created_at ASC").Find(&messages).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "查询消息失败"})
		return
	}

	// 查询用户信息，用于显示昵称等
	var user models.User
	var target models.User

	db.First(&user, userID)
	db.First(&target, targetID)

	// 构造响应数据
	var result []gin.H
	for _, msg := range messages {
		result = append(result, gin.H{
			"id":         msg.ID,
			"from_id":    msg.SenderID,
			"to_id":      msg.ReceiverID,
			"content":    msg.Content,
			"type":       msg.Type,
			"created_at": msg.CreatedAt,
			"from_nickname": func() string {
				if msg.SenderID == uint(userID) {
					return user.Nickname
				}
				return target.Nickname
			}(),
			"from_avatar": func() string {
				if msg.SenderID == uint(userID) {
					return user.Avatar
				}
				return target.Avatar
			}(),
		})
	}

	c.JSON(200, gin.H{"success": true, "data": result})
}

// 群聊消息发送
func GroupChat(c *gin.Context) {
	// 简化实现，实际应该处理群聊消息
	c.JSON(200, gin.H{"success": true, "msg": "群聊功能开发中"})
}

// 最近聊天列表
func GetRecentChats(c *gin.Context) {
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(400, gin.H{"success": false, "msg": "缺少user_id参数"})
		return
	}

	var userID uint
	if _, err := c.Get("user_id"); err {
		userID = c.MustGet("user_id").(uint)
	} else {
		// 尝试从查询参数转换
		var err error
		userID64, err := strconv.ParseUint(userIDStr, 10, 32)
		if err != nil {
			c.JSON(400, gin.H{"success": false, "msg": "无效的user_id参数"})
			return
		}
		userID = uint(userID64)
	}

	db := c.MustGet("db").(*gorm.DB)
	chats, err := repositories.GetRecentChats(db, userID)
	if err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "获取聊天列表失败"})
		return
	}

	c.JSON(200, gin.H{"success": true, "data": chats})
}

// 增量同步消息（多端同步/换设备用）
func SyncMessages(c *gin.Context) {
	var query struct {
		UserID    uint  `form:"user_id"`
		SinceTime int64 `form:"since"` // 拉取该时间戳之后的所有消息
	}
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var msgs []models.ChatMessage
	db.Where("(sender_id = ? OR receiver_id = ?) AND created_at > ?", query.UserID, query.UserID, query.SinceTime).
		Order("created_at asc").Find(&msgs)
	c.JSON(200, gin.H{"success": true, "data": msgs})
}
