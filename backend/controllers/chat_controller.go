package controllers

import (
	"allinone_backend/models"
	"allinone_backend/repositories"
	"allinone_backend/utils"
	"strconv"
	"strings"
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

	// 通过WebSocket推送实时消息
	// 使用WebSocketManager发送消息
	// 注意：实际部署时需要确保WebSocket服务已正确配置
	// 这里我们使用utils.PushMessageToUser函数发送消息
	go func() {
		// 构造消息
		wsMessage := map[string]any{
			"type": "new_message",
			"data": map[string]any{
				"id":         message.ID,
				"from_id":    message.SenderID,
				"to_id":      message.ReceiverID,
				"content":    message.Content,
				"type":       message.Type,
				"created_at": message.CreatedAt,
			},
		}
		// 发送消息到接收者
		utils.PushMessageToUser(uint(toID), wsMessage)
	}()

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
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(401, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		GroupID        uint   `json:"group_id" binding:"required"`
		Content        string `json:"content" binding:"required"`
		Type           string `json:"type" binding:"required"`
		MentionedUsers []uint `json:"mentioned_users"`
		Extra          string `json:"extra"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查用户是否在群组中
	db := c.MustGet("db").(*gorm.DB)
	var groupMember models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, userID).First(&groupMember).Error; err != nil {
		c.JSON(403, gin.H{"success": false, "msg": "您不是该群组成员"})
		return
	}

	// 检查群组是否存在
	var group models.Group
	if err := db.First(&group, req.GroupID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "群组不存在"})
		return
	}

	// 检查用户是否被禁言
	if groupMember.Muted {
		// 检查禁言是否已过期
		if groupMember.MutedUntil > 0 && groupMember.MutedUntil < time.Now().Unix() {
			// 禁言已过期，解除禁言
			groupMember.Muted = false
			groupMember.MutedUntil = 0
			db.Save(&groupMember)
		} else {
			c.JSON(403, gin.H{"success": false, "msg": "您已被禁言"})
			return
		}
	}

	// 处理@用户
	var mentionedUsersStr string
	if len(req.MentionedUsers) > 0 {
		// 检查被@的用户是否在群组中
		var validMentionedUsers []uint
		for _, mentionedUserID := range req.MentionedUsers {
			var mentionedGroupMember models.GroupMember
			if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, mentionedUserID).First(&mentionedGroupMember).Error; err == nil {
				validMentionedUsers = append(validMentionedUsers, mentionedUserID)
			}
		}

		// 将有效的@用户ID转换为字符串
		if len(validMentionedUsers) > 0 {
			for i, id := range validMentionedUsers {
				if i > 0 {
					mentionedUsersStr += ","
				}
				mentionedUsersStr += strconv.FormatUint(uint64(id), 10)
			}
		}
	}

	// 创建消息
	message := models.ChatMessage{
		SenderID:       userID.(uint),
		GroupID:        req.GroupID,
		Content:        req.Content,
		Type:           req.Type,
		Extra:          req.Extra,
		MentionedUsers: mentionedUsersStr,
		Status:         1, // 已发送
		CreatedAt:      time.Now().Unix(),
	}

	// 保存消息
	if err := db.Create(&message).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "消息保存失败"})
		return
	}

	// 更新群组成员的最后活跃时间
	groupMember.LastActive = time.Now().Unix()
	groupMember.IsActive = true
	db.Save(&groupMember)

	// 通过WebSocket推送实时消息
	// 向群组所有成员推送消息
	go func() {
		// 查询群组所有成员
		var groupMembers []models.GroupMember
		db.Where("group_id = ?", req.GroupID).Find(&groupMembers)

		// 构造消息
		wsMessage := map[string]any{
			"type": "new_group_message",
			"data": map[string]any{
				"id":              message.ID,
				"sender_id":       message.SenderID,
				"group_id":        message.GroupID,
				"content":         message.Content,
				"type":            message.Type,
				"extra":           message.Extra,
				"mentioned_users": message.MentionedUsers,
				"status":          message.Status,
				"created_at":      message.CreatedAt,
			},
		}

		// 向每个群成员推送消息
		for _, member := range groupMembers {
			// 不向发送者推送消息
			if member.UserID != userID.(uint) {
				utils.PushMessageToUser(member.UserID, wsMessage)
			}
		}
	}()

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "发送成功",
		"data": gin.H{
			"id":              message.ID,
			"sender_id":       message.SenderID,
			"group_id":        message.GroupID,
			"content":         message.Content,
			"type":            message.Type,
			"extra":           message.Extra,
			"mentioned_users": message.MentionedUsers,
			"status":          message.Status,
			"created_at":      message.CreatedAt,
		},
	})
}

// 获取群聊消息
func GetGroupMessages(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(401, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	groupIDStr := c.Query("group_id")
	limitStr := c.Query("limit")
	offsetStr := c.Query("offset")

	if groupIDStr == "" {
		c.JSON(400, gin.H{"success": false, "msg": "缺少group_id参数"})
		return
	}

	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的group_id参数"})
		return
	}

	// 设置默认值
	limit := 20
	offset := 0

	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	// 检查用户是否在群组中
	db := c.MustGet("db").(*gorm.DB)
	var groupMember models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&groupMember).Error; err != nil {
		c.JSON(403, gin.H{"success": false, "msg": "您不是该群组成员"})
		return
	}

	// 查询群组消息
	var messages []models.ChatMessage
	if err := db.Where("group_id = ?", groupID).Order("created_at DESC").Limit(limit).Offset(offset).Find(&messages).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "查询消息失败"})
		return
	}

	// 获取发送者信息
	var senderIDs []uint
	for _, msg := range messages {
		senderIDs = append(senderIDs, msg.SenderID)
	}

	// 查询发送者信息
	var users []models.User
	db.Where("id IN ?", senderIDs).Find(&users)

	// 构建用户映射
	userMap := make(map[uint]models.User)
	for _, user := range users {
		userMap[user.ID] = user
	}

	// 构造响应数据
	var result []gin.H
	for _, msg := range messages {
		sender, exists := userMap[msg.SenderID]
		senderNickname := ""
		senderAvatar := ""
		if exists {
			senderNickname = sender.Nickname
			senderAvatar = sender.Avatar
		}

		// 处理@用户
		var mentionedUsersList []uint
		if msg.MentionedUsers != "" {
			mentionedUsersStr := strings.Split(msg.MentionedUsers, ",")
			for _, idStr := range mentionedUsersStr {
				if id, err := strconv.ParseUint(idStr, 10, 32); err == nil {
					mentionedUsersList = append(mentionedUsersList, uint(id))
				}
			}
		}

		result = append(result, gin.H{
			"id":              msg.ID,
			"sender_id":       msg.SenderID,
			"group_id":        msg.GroupID,
			"content":         msg.Content,
			"type":            msg.Type,
			"extra":           msg.Extra,
			"mentioned_users": mentionedUsersList,
			"status":          msg.Status,
			"created_at":      msg.CreatedAt,
			"sender_nickname": senderNickname,
			"sender_avatar":   senderAvatar,
			"is_mentioned":    strings.Contains(msg.MentionedUsers, strconv.FormatUint(uint64(userID.(uint)), 10)),
		})
	}

	// 更新群组成员的最后活跃时间
	groupMember.LastActive = time.Now().Unix()
	groupMember.IsActive = true
	db.Save(&groupMember)

	c.JSON(200, gin.H{"success": true, "data": result})
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
