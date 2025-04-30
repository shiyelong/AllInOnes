package repositories

import (
	"allinone_backend/models"
	"gorm.io/gorm"
)

// 保存消息到数据库
func SaveMessage(db *gorm.DB, msg *models.ChatMessage) error {
	return db.Create(msg).Error
}

// 查询两用户间历史消息
func GetMessagesBetweenUsers(db *gorm.DB, uid1, uid2 uint) ([]models.ChatMessage, error) {
	var msgs []models.ChatMessage
	err := db.Where(
		"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
		uid1, uid2, uid2, uid1,
	).Order("created_at asc").Find(&msgs).Error
	return msgs, err
}
