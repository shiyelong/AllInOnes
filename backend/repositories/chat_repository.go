package repositories

import (
	"allinone_backend/models"

	"gorm.io/gorm"
)

// 获取用户的最近聊天列表
func GetRecentChats(db *gorm.DB, userID uint) ([]map[string]interface{}, error) {
	// 这里简化实现，实际应该是一个复杂的SQL查询，按最近聊天时间排序
	var result []map[string]interface{}

	// 查询最近发送消息的用户
	rows, err := db.Raw(`
		SELECT
			CASE
				WHEN sender_id = ? THEN receiver_id
				ELSE sender_id
			END as peer_id,
			MAX(created_at) as last_time
		FROM chat_messages
		WHERE sender_id = ? OR receiver_id = ?
		GROUP BY peer_id
		ORDER BY last_time DESC
	`, userID, userID, userID).Rows()

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var peerID uint
		var lastTime int64
		rows.Scan(&peerID, &lastTime)

		// 查询最后一条消息
		var lastMsg models.ChatMessage
		db.Where(
			"((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND created_at = ?",
			userID, peerID, peerID, userID, lastTime,
		).First(&lastMsg)

		// 查询对方用户信息
		var peer models.User
		db.First(&peer, peerID)

		// 查询未读消息数
		var unreadCount int64
		db.Model(&models.ChatMessage{}).Where(
			"sender_id = ? AND receiver_id = ? AND read_at = 0",
			peerID, userID,
		).Count(&unreadCount)

		result = append(result, map[string]interface{}{
			"peer_id":      peerID,
			"peer_name":    peer.Account,
			"last_message": lastMsg.Content,
			"last_time":    lastMsg.CreatedAt,
			"unread_count": unreadCount,
		})
	}

	return result, nil
}
