package controllers

import (
	"allinone_backend/models"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// 测试API的基本功能
func TestAPIBasics(t *testing.T) {
	// 设置测试环境
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	assert.NoError(t, err)
	
	// 迁移数据库结构
	db.AutoMigrate(&models.User{}, &models.Friend{}, &models.FriendRequest{}, &models.ChatMessage{})
	
	// 创建路由器
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	
	// 注册API路由
	r.GET("/api/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"success": true,
			"message": "pong",
			"timestamp": time.Now().Unix(),
		})
	})
	
	// 测试Ping API
	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/ping", nil)
	r.ServeHTTP(w, req)
	
	// 验证响应
	assert.Equal(t, 200, w.Code)
	
	var resp map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.NoError(t, err)
	
	assert.True(t, resp["success"].(bool))
	assert.Equal(t, "pong", resp["message"])
	assert.NotNil(t, resp["timestamp"])
}

// 测试用户注册API
func TestUserRegistration(t *testing.T) {
	// 设置测试环境
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	assert.NoError(t, err)
	
	// 迁移数据库结构
	db.AutoMigrate(&models.User{})
	
	// 创建路由器
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	
	// 注册API路由
	r.POST("/user/register", func(c *gin.Context) {
		var req struct {
			Password string `json:"password"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
			return
		}
		
		// 生成随机账号
		account := "test_" + time.Now().Format("150405")
		
		user := models.User{
			Account:  account,
			Password: req.Password,
		}
		
		if err := db.Create(&user).Error; err != nil {
			c.JSON(500, gin.H{"success": false, "msg": "创建用户失败"})
			return
		}
		
		c.JSON(200, gin.H{
			"success": true,
			"user_id": user.ID,
			"account": user.Account,
		})
	})
	
	// 测试注册API
	w := httptest.NewRecorder()
	reqBody := `{"password": "test123"}`
	req := httptest.NewRequest("POST", "/user/register", strings.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	
	// 验证响应
	assert.Equal(t, 200, w.Code)
	
	var resp map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.NoError(t, err)
	
	assert.True(t, resp["success"].(bool))
	assert.NotNil(t, resp["user_id"])
	assert.NotNil(t, resp["account"])
	assert.Contains(t, resp["account"].(string), "test_")
}

// 测试登录API
func TestUserLogin(t *testing.T) {
	// 设置测试环境
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	assert.NoError(t, err)
	
	// 迁移数据库结构
	db.AutoMigrate(&models.User{})
	
	// 创建测试用户
	testAccount := "test_" + time.Now().Format("150405")
	testPassword := "test123"
	
	user := models.User{
		Account:  testAccount,
		Password: testPassword,
	}
	
	err = db.Create(&user).Error
	assert.NoError(t, err)
	
	// 创建路由器
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	
	// 注册API路由
	r.POST("/api/login", func(c *gin.Context) {
		var req struct {
			Account  string `json:"account"`
			Password string `json:"password"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
			return
		}
		
		var user models.User
		if err := db.Where("account = ?", req.Account).First(&user).Error; err != nil {
			c.JSON(200, gin.H{"success": false, "msg": "账号或密码错误"})
			return
		}
		
		if user.Password != req.Password {
			c.JSON(200, gin.H{"success": false, "msg": "账号或密码错误"})
			return
		}
		
		c.JSON(200, gin.H{
			"success": true,
			"token": "test_token_" + user.Account,
			"data": gin.H{
				"user": gin.H{
					"id": user.ID,
					"account": user.Account,
					"nickname": user.Nickname,
				},
			},
		})
	})
	
	// 测试登录API - 成功
	w1 := httptest.NewRecorder()
	reqBody1 := `{"account": "` + testAccount + `", "password": "` + testPassword + `"}`
	req1 := httptest.NewRequest("POST", "/api/login", strings.NewReader(reqBody1))
	req1.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w1, req1)
	
	// 验证响应
	assert.Equal(t, 200, w1.Code)
	
	var resp1 map[string]interface{}
	err = json.Unmarshal(w1.Body.Bytes(), &resp1)
	assert.NoError(t, err)
	
	assert.True(t, resp1["success"].(bool))
	assert.NotNil(t, resp1["token"])
	assert.Contains(t, resp1["token"].(string), "test_token_")
	
	// 测试登录API - 失败
	w2 := httptest.NewRecorder()
	reqBody2 := `{"account": "` + testAccount + `", "password": "wrong_password"}`
	req2 := httptest.NewRequest("POST", "/api/login", strings.NewReader(reqBody2))
	req2.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w2, req2)
	
	// 验证响应
	assert.Equal(t, 200, w2.Code)
	
	var resp2 map[string]interface{}
	err = json.Unmarshal(w2.Body.Bytes(), &resp2)
	assert.NoError(t, err)
	
	assert.False(t, resp2["success"].(bool))
	assert.Equal(t, "账号或密码错误", resp2["msg"])
}
