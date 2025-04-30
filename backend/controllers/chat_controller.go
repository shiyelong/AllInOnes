package controllers

import (
	"github.com/gin-gonic/gin"
	"allinone_backend/models"
	"allinone_backend/repositories"
	"time"
	"gorm.io/gorm"
)

// 聊天相关接口
// 聊天相关接口
func SingleChat(c *gin.Context) {
	// 单聊消息发送，兼容多媒体类型
	var msg struct {
		SenderID   uint   `json:"sender_id"`
		ReceiverID uint   `json:"receiver_id"`
		Content    string `json:"content"`
		Type       string `json:"type"`
		Extra      string `json:"extra"`
	}
	if err := c.ShouldBindJSON(&msg); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	m := models.ChatMessage{
		SenderID:   msg.SenderID,
		ReceiverID: msg.ReceiverID,
		Content:    msg.Content,
		Type:       msg.Type,
		CreatedAt:  time.Now().Unix(),
	}
	db := c.MustGet("db").(*gorm.DB)
	if err := repositories.SaveMessage(db, &m); err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "消息保存失败"})
		return
	}
	// TODO: WebSocket 推送实时消息
	c.JSON(200, gin.H{"success": true, "msg": "发送成功", "data": m})
}

// 拉取历史消息
func GetMessagesByUser(c *gin.Context) {
	var query struct {
		UserID uint `form:"user_id"` // 当前用户
		PeerID uint `form:"peer_id"` // 对方用户
	}
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	msgs, err := repositories.GetMessagesBetweenUsers(db, query.UserID, query.PeerID)
	if err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "查询失败"})
		return
	}
	c.JSON(200, gin.H{"success": true, "data": msgs})
}
func GroupChat(c *gin.Context) {}

// 最近聊天列表
func GetRecentChats(c *gin.Context) {
	// TODO: 查询最近会话表或按消息聚合
	c.JSON(200, gin.H{"success": true, "data": []interface{}{}})
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
