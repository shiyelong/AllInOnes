package controllers

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"allinone_backend/models"
	"strconv"
	"time"
)

// 用户注册：自动分配纯数字账号（6~12位）
func RegisterUser(c *gin.Context) {
	var req struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	user := models.User{
		Password: req.Password,
		CreatedAt: time.Now().Unix(),
	}
	if err := db.Create(&user).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "注册失败"})
		return
	}
	// 纯数字账号生成（如QQ号，100000起步，保证唯一）
	account := strconv.Itoa(100000 + int(user.ID))
	db.Model(&user).Update("Account", account)
	c.JSON(200, gin.H{"success": true, "msg": "注册成功", "account": account, "user_id": user.ID})
}

// 通过账号查找用户ID
func GetUserByAccount(c *gin.Context) {
	account := c.Query("account")
	if account == "" {
		c.JSON(400, gin.H{"success": false, "msg": "参数缺失"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var user models.User
	if err := db.Where("account = ?", account).First(&user).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "账号不存在"})
		return
	}
	c.JSON(200, gin.H{"success": true, "user_id": user.ID, "account": user.Account})
}
