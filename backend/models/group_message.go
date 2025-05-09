package models

import (
	"time"
)

// GroupMessage 群聊消息模型
type GroupMessage struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	GroupID   uint   `json:"group_id" gorm:"index"`
	SenderID  uint   `json:"sender_id" gorm:"index"`
	Content   string `json:"content"`
	Type      string `json:"type" gorm:"default:text"` // text, image, file, etc.
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
	DeletedAt int64  `json:"deleted_at" gorm:"index"`
}

// TableName 指定表名
func (GroupMessage) TableName() string {
	return "group_messages"
}

// BeforeCreate 创建前的钩子
func (m *GroupMessage) BeforeCreate() error {
	now := time.Now().Unix()
	if m.CreatedAt == 0 {
		m.CreatedAt = now
	}
	m.UpdatedAt = now
	return nil
}

// BeforeUpdate 更新前的钩子
func (m *GroupMessage) BeforeUpdate() error {
	m.UpdatedAt = time.Now().Unix()
	return nil
}

// GroupMessageMention @用户记录
type GroupMessageMention struct {
	ID        uint `json:"id" gorm:"primaryKey"`
	MessageID uint `json:"message_id" gorm:"index"`
	UserID    uint `json:"user_id" gorm:"index"`
	CreatedAt int64 `json:"created_at"`
}

// TableName 指定表名
func (GroupMessageMention) TableName() string {
	return "group_message_mentions"
}

// BeforeCreate 创建前的钩子
func (m *GroupMessageMention) BeforeCreate() error {
	if m.CreatedAt == 0 {
		m.CreatedAt = time.Now().Unix()
	}
	return nil
}
