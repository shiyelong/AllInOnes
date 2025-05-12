package services

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"time"

	"gorm.io/gorm"
)

// 聊天服务相关逻辑
// 提供单聊和群聊消息发送的服务层功能

// SendSingleMessage 发送单聊消息
// 保存消息到数据库并通过WebSocket推送给接收者
func SendSingleMessage(db *gorm.DB, msg *models.ChatMessage) error {
	// 设置消息创建时间
	if msg.CreatedAt == 0 {
		msg.CreatedAt = time.Now().Unix()
	}

	// 过滤敏感词
	msg.Content = utils.FilterSensitiveWords(msg.Content)

	// 保存消息到数据库
	if err := db.Create(msg).Error; err != nil {
		return err
	}

	// 通过WebSocket推送消息
	go func() {
		// 构造WebSocket消息
		wsMessage := map[string]any{
			"type": "new_message",
			"data": map[string]any{
				"id":         msg.ID,
				"from_id":    msg.SenderID,
				"to_id":      msg.ReceiverID,
				"content":    msg.Content,
				"type":       msg.Type,
				"created_at": msg.CreatedAt,
			},
		}

		// 推送消息给接收者
		utils.PushMessageToUser(msg.ReceiverID, wsMessage)
	}()

	return nil
}

// SendGroupMessage 发送群聊消息
// 保存消息到数据库并通过WebSocket推送给群组所有成员
func SendGroupMessage(db *gorm.DB, msg *models.ChatMessage) error {
	// 设置消息创建时间
	if msg.CreatedAt == 0 {
		msg.CreatedAt = time.Now().Unix()
	}

	// 过滤敏感词
	msg.Content = utils.FilterSensitiveWords(msg.Content)

	// 保存消息到数据库
	if err := db.Create(msg).Error; err != nil {
		return err
	}

	// 通过WebSocket推送消息
	go func() {
		// 查询群组所有成员
		var groupMembers []models.GroupMember
		db.Where("group_id = ?", msg.GroupID).Find(&groupMembers)

		// 构造WebSocket消息
		wsMessage := map[string]any{
			"type": "new_group_message",
			"data": map[string]any{
				"id":              msg.ID,
				"sender_id":       msg.SenderID,
				"group_id":        msg.GroupID,
				"content":         msg.Content,
				"type":            msg.Type,
				"extra":           msg.Extra,
				"mentioned_users": msg.MentionedUsers,
				"status":          msg.Status,
				"created_at":      msg.CreatedAt,
			},
		}

		// 向每个群成员推送消息
		for _, member := range groupMembers {
			// 不向发送者推送消息
			if member.UserID != msg.SenderID {
				utils.PushMessageToUser(member.UserID, wsMessage)
			}
		}
	}()

	return nil
}
