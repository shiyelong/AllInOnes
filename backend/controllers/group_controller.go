package controllers

import (
	"github.com/gin-gonic/gin"
	"allinone_backend/models"
	"gorm.io/gorm"
	"time"
)

// 创建群聊
func CreateGroup(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		Name    string   `json:"name"`
		OwnerID uint     `json:"owner_id"`
		Avatar  string   `json:"avatar"`
		Notice  string   `json:"notice"`
		Members []uint   `json:"members"` // 包含owner
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	group := models.Group{
		Name: req.Name,
		OwnerID: req.OwnerID,
		Avatar: req.Avatar,
		Notice: req.Notice,
		CreatedAt: time.Now().Unix(),
	}
	if err := db.Create(&group).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "群聊创建失败"})
		return
	}
	// 添加群成员
	var members []models.GroupMember
	for _, uid := range req.Members {
		role := "member"
		if uid == req.OwnerID { role = "owner" }
		members = append(members, models.GroupMember{GroupID: group.ID, UserID: uid, Role: role})
	}
	if len(members) > 0 {
		db.Create(&members)
	}
	c.JSON(200, gin.H{"success": true, "msg": "群聊创建成功", "data": group})
}
