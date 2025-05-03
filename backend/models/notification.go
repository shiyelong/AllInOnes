package models

// Notification 通知模型
type Notification struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	UserID    uint   `json:"user_id" gorm:"index"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Type      string `json:"type" gorm:"index"` // 通知类型: transaction, system, etc.
	Status    string `json:"status" gorm:"index"` // 通知状态: unread, read
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}
