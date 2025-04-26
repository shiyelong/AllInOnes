package models

// 聊天消息数据模型

type ChatMessage struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	SenderID  uint   `json:"sender_id"`
	ReceiverID uint  `json:"receiver_id"`
	GroupID   uint   `json:"group_id"`
	Content   string `json:"content"`
	Type      string `json:"type"` // text, image, etc
	CreatedAt int64  `json:"created_at"`
}
