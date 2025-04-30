package controllers

import (
	"github.com/gin-gonic/gin"
	"time"
	"gorm.io/gorm"
	"strconv"
	"allinone_backend/models"
)

// 好友/联系人相关接口
// 获取好友列表
func GetFriends(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)
	db := c.MustGet("db").(*gorm.DB)
	var friends []models.Friend
	db.Where("user_id = ?", userID).Find(&friends)
	var resp []gin.H
	for _, f := range friends {
		resp = append(resp, gin.H{
			"friend_id": f.FriendID,
			"created_at": f.CreatedAt,
			"blocked": f.Blocked,
		})
	}
	c.JSON(200, gin.H{"success": true, "data": resp})
}

// 屏蔽好友
func BlockFriend(c *gin.Context) {
	var req struct {
		UserID   uint `json:"user_id"`
		FriendID uint `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "好友关系不存在"})
		return
	}
	friend.Blocked = 1
	db.Save(&friend)
	c.JSON(200, gin.H{"success": true, "msg": "已屏蔽该好友"})
}

// 取消屏蔽
func UnblockFriend(c *gin.Context) {
	var req struct {
		UserID   uint `json:"user_id"`
		FriendID uint `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "好友关系不存在"})
		return
	}
	friend.Blocked = 0
	db.Save(&friend)
	c.JSON(200, gin.H{"success": true, "msg": "已取消屏蔽"})
}

// 添加好友
func AddFriend(c *gin.Context) {
	var req struct {
		UserID   uint `json:"user_id"`
		FriendID uint `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var targetUser models.User
	if err := db.First(&targetUser, req.FriendID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "目标用户不存在"})
		return
	}
	if targetUser.FriendAddMode == 0 {
		// 自动同意，直接加好友（互加）
		db.Create(&models.Friend{UserID: req.UserID, FriendID: req.FriendID, CreatedAt: time.Now().Unix()})
		db.Create(&models.Friend{UserID: req.FriendID, FriendID: req.UserID, CreatedAt: time.Now().Unix()})
		c.JSON(200, gin.H{"success": true, "msg": "已加为好友"})
		return
	}
	// 需验证，写入好友请求表
	db.Create(&models.FriendRequest{FromID: req.UserID, ToID: req.FriendID, Status: 0, CreatedAt: time.Now().Unix()})
	c.JSON(200, gin.H{"success": true, "msg": "好友请求已发送，等待对方同意"})
}

// 查询加好友方式
func GetFriendAddMode(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)
	db := c.MustGet("db").(*gorm.DB)
	var user models.User
	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "用户不存在"})
		return
	}
	c.JSON(200, gin.H{"success": true, "mode": user.FriendAddMode})
}

// 设置加好友方式
func SetFriendAddMode(c *gin.Context) {
	var req struct {
		UserID uint `json:"user_id"`
		Mode   int  `json:"mode"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	if err := db.Model(&models.User{}).Where("id = ?", req.UserID).Update("friend_add_mode", req.Mode).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "设置失败"})
		return
	}
	c.JSON(200, gin.H{"success": true, "msg": "设置成功"})
}

// 查询我的好友请求
func GetFriendRequests(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)
	db := c.MustGet("db").(*gorm.DB)
	var reqs []models.FriendRequest
	db.Where("to_id = ? AND status = 0", userID).Find(&reqs)
	c.JSON(200, gin.H{"success": true, "data": reqs})
}

// 同意好友请求
func AgreeFriendRequest(c *gin.Context) {
	var req struct {
		RequestID uint `json:"request_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var fr models.FriendRequest
	if err := db.First(&fr, req.RequestID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "请求不存在"})
		return
	}
	if fr.Status != 0 {
		c.JSON(400, gin.H{"success": false, "msg": "请求已处理"})
		return
	}
	db.Model(&fr).Update("status", 1)
	db.Create(&models.Friend{UserID: fr.FromID, FriendID: fr.ToID, CreatedAt: time.Now().Unix()})
	db.Create(&models.Friend{UserID: fr.ToID, FriendID: fr.FromID, CreatedAt: time.Now().Unix()})
	c.JSON(200, gin.H{"success": true, "msg": "已同意好友请求"})
}
