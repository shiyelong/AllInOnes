package repositories

import "allinone_backend/models"

// 聊天消息数据库操作
func SaveMessage(msg *models.ChatMessage) error {
	// TODO: 保存消息到数据库
	return nil
}

func GetMessagesByUser(userID uint) ([]models.ChatMessage, error) {
	// TODO: 查询用户相关消息
	return nil, nil
}

func GetMessagesByGroup(groupID uint) ([]models.ChatMessage, error) {
	// TODO: 查询群聊相关消息
	return nil, nil
}
