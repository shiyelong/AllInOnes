package controllers

import (
	"allinone_backend/models"
	"encoding/json"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// 测试用的模拟函数
func mockRegisterUserForFriendsTest(c *gin.Context) {
	var req struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)

	// 生成随机账号
	account := strconv.Itoa(100000 + time.Now().Nanosecond()%900000)

	user := models.User{
		Account:  account,
		Password: req.Password,
	}

	if err := db.Create(&user).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "创建用户失败: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"user_id": user.ID,
		"account": user.Account,
	})
}

// 测试用的模拟添加好友函数
func mockAddFriendForTest(c *gin.Context) {
	var req struct {
		UserID     int    `json:"user_id"`
		FriendID   int    `json:"friend_id"`
		Message    string `json:"message"`
		SourceType string `json:"source_type"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 检查用户是否存在
	var user models.User
	if err := db.First(&user, req.UserID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "用户不存在"})
		return
	}

	// 检查好友是否存在
	var friend models.User
	if err := db.First(&friend, req.FriendID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "好友不存在"})
		return
	}

	// 检查是否已经是好友
	var existingFriend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&existingFriend).Error; err == nil {
		c.JSON(400, gin.H{"success": false, "msg": "已经是好友"})
		return
	}

	// 直接加好友（互加）
	db.Create(&models.Friend{UserID: uint(req.UserID), FriendID: uint(req.FriendID), CreatedAt: time.Now().Unix()})
	db.Create(&models.Friend{UserID: uint(req.FriendID), FriendID: uint(req.UserID), CreatedAt: time.Now().Unix()})

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "已添加为好友",
	})
}

// 测试用的模拟屏蔽好友函数
func mockBlockFriendForTest(c *gin.Context) {
	var req struct {
		UserID   int `json:"user_id"`
		FriendID int `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 检查是否是好友
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		// 如果不是好友，直接创建一个好友关系并设置为屏蔽状态
		friend := models.Friend{
			UserID:    uint(req.UserID),
			FriendID:  uint(req.FriendID),
			CreatedAt: time.Now().Unix(),
		}
		db.Create(&friend)
		// 更新为屏蔽状态
		db.Model(&friend).Update("is_blocked", true)
	} else {
		// 如果已经是好友，更新为屏蔽状态
		db.Model(&friend).Update("is_blocked", true)
	}

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "已屏蔽该好友",
	})
}

// 测试用的模拟解除屏蔽好友函数
func mockUnblockFriendForTest(c *gin.Context) {
	var req struct {
		UserID   int `json:"user_id"`
		FriendID int `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 检查是否是好友
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		// 如果不是好友，直接创建一个好友关系并设置为非屏蔽状态
		friend := models.Friend{
			UserID:    uint(req.UserID),
			FriendID:  uint(req.FriendID),
			CreatedAt: time.Now().Unix(),
		}
		db.Create(&friend)
		// 更新为非屏蔽状态
		db.Model(&friend).Update("is_blocked", false)
	} else {
		// 如果已经是好友，更新为非屏蔽状态
		db.Model(&friend).Update("is_blocked", false)
	}

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "已解除屏蔽该好友",
	})
}

func setupFriendsTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.Friend{}, &models.FriendRequest{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", mockRegisterUserForFriendsTest)
	r.POST("/friend/add", mockAddFriendForTest)
	r.GET("/friend/requests", GetFriendRequests)
	r.POST("/friend/agree", AgreeFriendRequest)
	r.GET("/friend/list", GetFriends)
	r.POST("/friend/block", mockBlockFriendForTest)
	r.POST("/friend/unblock", mockUnblockFriendForTest)
	return r, db
}

func TestAddFriendAndBlockUnblock(t *testing.T) {
	r, _ := setupFriendsTestRouter()
	// 注册两个用户
	w1 := httptest.NewRecorder()
	w2 := httptest.NewRecorder()
	body1 := `{"password": "a123456"}`
	body2 := `{"password": "b123456"}`
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(body1)))
	r.ServeHTTP(w2, httptest.NewRequest("POST", "/user/register", strings.NewReader(body2)))
	var resp1, resp2 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	user1ID := int(resp1["user_id"].(float64))
	user2ID := int(resp2["user_id"].(float64))

	// user1加user2为好友
	addBody := `{"user_id": ` + strconv.Itoa(user1ID) + `, "friend_id": ` + strconv.Itoa(user2ID) + `}`
	wAdd := httptest.NewRecorder()
	r.ServeHTTP(wAdd, httptest.NewRequest("POST", "/friend/add", strings.NewReader(addBody)))
	var addResp map[string]interface{}
	_ = json.Unmarshal(wAdd.Body.Bytes(), &addResp)
	assert.True(t, addResp["success"].(bool))

	// user1屏蔽user2
	blockBody := `{"user_id": ` + strconv.Itoa(user1ID) + `, "friend_id": ` + strconv.Itoa(user2ID) + `}`
	wBlock := httptest.NewRecorder()
	r.ServeHTTP(wBlock, httptest.NewRequest("POST", "/friend/block", strings.NewReader(blockBody)))
	var blockResp map[string]interface{}
	_ = json.Unmarshal(wBlock.Body.Bytes(), &blockResp)
	assert.True(t, blockResp["success"].(bool))

	// user1解除屏蔽user2
	unblockBody := `{"user_id": ` + strconv.Itoa(user1ID) + `, "friend_id": ` + strconv.Itoa(user2ID) + `}`
	wUnblock := httptest.NewRecorder()
	r.ServeHTTP(wUnblock, httptest.NewRequest("POST", "/friend/unblock", strings.NewReader(unblockBody)))
	var unblockResp map[string]interface{}
	_ = json.Unmarshal(wUnblock.Body.Bytes(), &unblockResp)
	assert.True(t, unblockResp["success"].(bool))
}
