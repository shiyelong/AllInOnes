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
func mockRegisterUserForFriendTest(c *gin.Context) {
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
func mockAddFriend(c *gin.Context) {
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

	// 根据目标用户的好友添加模式处理
	switch friend.FriendAddMode {
	case 0: // 自动同意
		// 直接加好友（互加）
		db.Create(&models.Friend{UserID: uint(req.UserID), FriendID: uint(req.FriendID), CreatedAt: time.Now().Unix()})
		db.Create(&models.Friend{UserID: uint(req.FriendID), FriendID: uint(req.UserID), CreatedAt: time.Now().Unix()})

		c.JSON(200, gin.H{
			"success":       true,
			"msg":           "已自动添加为好友",
			"auto_accepted": true,
		})
		return

	case 1: // 需要验证
		// 写入好友请求表
		friendRequest := models.FriendRequest{
			FromID:     uint(req.UserID),
			ToID:       uint(req.FriendID),
			Status:     0, // 待处理
			Message:    req.Message,
			SourceType: req.SourceType,
			CreatedAt:  time.Now().Unix(),
		}
		db.Create(&friendRequest)

		c.JSON(200, gin.H{
			"success":       true,
			"msg":           "好友请求已发送，等待对方同意",
			"auto_accepted": false,
		})
		return

	default:
		c.JSON(400, gin.H{"success": false, "msg": "未知的好友添加模式"})
		return
	}
}

// 测试用的模拟获取好友请求函数
func mockGetFriendRequests(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)

	db := c.MustGet("db").(*gorm.DB)

	var requests []models.FriendRequest
	db.Where("to_id = ? AND status = 0", userID).Find(&requests)

	c.JSON(200, gin.H{
		"success": true,
		"data":    requests,
	})
}

// 测试用的模拟同意好友请求函数
func mockAgreeFriendRequest(c *gin.Context) {
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

	// 更新请求状态为已同意
	db.Model(&fr).Update("status", 1)

	// 创建好友关系（双向）
	db.Create(&models.Friend{UserID: fr.FromID, FriendID: fr.ToID, CreatedAt: time.Now().Unix()})
	db.Create(&models.Friend{UserID: fr.ToID, FriendID: fr.FromID, CreatedAt: time.Now().Unix()})

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "已同意好友请求",
	})
}

func setupFriendRequestTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.Friend{}, &models.FriendRequest{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", mockRegisterUserForFriendTest)
	r.POST("/friend/add", mockAddFriend)
	r.GET("/friend/requests", mockGetFriendRequests)
	r.POST("/friend/agree", mockAgreeFriendRequest)
	return r, db
}

func TestFriendRequestAndAgree(t *testing.T) {
	r, db := setupFriendRequestTestRouter()
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

	// 设置 user2 需要验证加好友
	db.Model(&models.User{}).Where("id = ?", user2ID).Update("friend_add_mode", 1)

	// user1加user2为好友（假设user2需要验证）
	addBody := `{"user_id": ` + strconv.Itoa(user1ID) + `, "friend_id": ` + strconv.Itoa(user2ID) + `}`
	wAdd := httptest.NewRecorder()
	r.ServeHTTP(wAdd, httptest.NewRequest("POST", "/friend/add", strings.NewReader(addBody)))
	var addResp map[string]interface{}
	_ = json.Unmarshal(wAdd.Body.Bytes(), &addResp)
	assert.True(t, addResp["success"].(bool))

	// user2拉取好友请求
	wReq := httptest.NewRecorder()
	r.ServeHTTP(wReq, httptest.NewRequest("GET", "/friend/requests?user_id="+strconv.Itoa(user2ID), nil))
	var reqResp map[string]interface{}
	_ = json.Unmarshal(wReq.Body.Bytes(), &reqResp)
	assert.True(t, reqResp["success"].(bool))

	// 打印完整的响应以便调试
	respBytes, _ := json.MarshalIndent(reqResp, "", "  ")
	t.Logf("Full response: %s", string(respBytes))

	// 检查data字段是否存在且为数组
	data, ok := reqResp["data"]
	assert.True(t, ok, "response should have data field")

	// 将data转换为数组
	requests, ok := data.([]interface{})
	assert.True(t, ok, "data field should be an array")
	assert.Greater(t, len(requests), 0, "should have at least one friend request")

	// 获取第一个请求
	reqMap, ok := requests[0].(map[string]interface{})
	assert.True(t, ok, "request should be a map")
	t.Logf("request object: %+v", reqMap)

	// 尝试获取ID字段（可能是ID或id）
	var requestID int
	if id, ok := reqMap["ID"]; ok {
		requestID = int(id.(float64))
	} else if id, ok := reqMap["id"]; ok {
		requestID = int(id.(float64))
	} else {
		// 如果找不到ID字段，尝试使用其他字段
		for key, val := range reqMap {
			if strings.ToLower(key) == "id" {
				requestID = int(val.(float64))
				break
			}
		}
	}

	// 确保requestID有值
	assert.NotEqual(t, 0, requestID, "could not find request ID in response")

	// user2同意好友请求
	agreeBody := `{"request_id": ` + strconv.Itoa(requestID) + `}`
	wAgree := httptest.NewRecorder()
	r.ServeHTTP(wAgree, httptest.NewRequest("POST", "/friend/agree", strings.NewReader(agreeBody)))
	var agreeResp map[string]interface{}
	_ = json.Unmarshal(wAgree.Body.Bytes(), &agreeResp)
	assert.True(t, agreeResp["success"].(bool))
}
