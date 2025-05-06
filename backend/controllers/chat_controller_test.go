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
func mockRegisterUser(c *gin.Context) {
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

// 测试用的模拟发送消息函数
func mockSendMessage(c *gin.Context) {
	var req struct {
		FromID  string `json:"from_id"`
		ToID    string `json:"to_id"`
		Content string `json:"content"`
		Type    string `json:"type"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 转换ID
	fromID, err := strconv.ParseUint(req.FromID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的发送者ID"})
		return
	}

	toID, err := strconv.ParseUint(req.ToID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的接收者ID"})
		return
	}

	// 创建消息
	message := models.ChatMessage{
		SenderID:   uint(fromID),
		ReceiverID: uint(toID),
		Content:    req.Content,
		Type:       req.Type,
		CreatedAt:  time.Now().Unix(),
	}

	// 保存消息
	db := c.MustGet("db").(*gorm.DB)
	if err := db.Create(&message).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "消息保存失败"})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"msg":     "发送成功",
		"data": gin.H{
			"id":         message.ID,
			"from_id":    message.SenderID,
			"to_id":      message.ReceiverID,
			"content":    message.Content,
			"type":       message.Type,
			"created_at": message.CreatedAt,
		},
	})
}

// 测试用的模拟同步消息函数
func mockSyncMessages(c *gin.Context) {
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

func setupChatTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.ChatMessage{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", mockRegisterUser)
	r.POST("/chat/single", mockSendMessage)
	r.GET("/chat/sync", mockSyncMessages)
	return r, db
}

func TestSendAndSyncChatMessage(t *testing.T) {
	r, _ := setupChatTestRouter()
	// 注册两个用户
	w1 := httptest.NewRecorder()
	body := `{"password": "a123456"}`
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(body)))
	var resp1 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	user1ID := int(resp1["user_id"].(float64))
	user2ID := 0
	{
		w := httptest.NewRecorder()
		body2 := `{"password": "b123456"}`
		r.ServeHTTP(w, httptest.NewRequest("POST", "/user/register", strings.NewReader(body2)))
		var resp2 map[string]interface{}
		_ = json.Unmarshal(w.Body.Bytes(), &resp2)
		user2ID = int(resp2["user_id"].(float64))
	}
	// user1向user2发送消息（用to_id字段）
	msgBody := `{"from_id": "` + strconv.Itoa(user1ID) + `", "to_id": "` + strconv.Itoa(user2ID) + `", "content": "hello", "type": "text"}`
	t.Logf("发送消息请求体: %s", msgBody)
	w3 := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/chat/single", strings.NewReader(msgBody))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w3, req)
	t.Logf("发送消息响应: %s", w3.Body.String())
	assert.Equal(t, 200, w3.Code)
	var resp3 map[string]interface{}
	_ = json.Unmarshal(w3.Body.Bytes(), &resp3)
	assert.True(t, resp3["success"].(bool))

	// user2同步消息（用user2的user_id）
	time.Sleep(10 * time.Millisecond)
	w4 := httptest.NewRecorder()
	r.ServeHTTP(w4, httptest.NewRequest("GET", "/chat/sync?user_id="+strconv.Itoa(user2ID)+"&since=0", nil))
	assert.Equal(t, 200, w4.Code)
	var resp4 map[string]interface{}
	_ = json.Unmarshal(w4.Body.Bytes(), &resp4)
	assert.True(t, resp4["success"].(bool))
	msgs := resp4["data"].([]interface{})
	assert.True(t, len(msgs) > 0)
}
