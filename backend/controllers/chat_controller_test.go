package controllers

import (
	"net/http/httptest"
	"testing"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"allinone_backend/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"encoding/json"
	"strings"
	"strconv"
	"time"
)

func setupChatTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.ChatMessage{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", RegisterUser)
	r.POST("/chat/single", SingleChat)
	r.GET("/chat/sync", SyncMessages)
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
	// user1向user2发送消息（用receiver_id字段）
	msgBody := `{"sender_id": ` + strconv.Itoa(user1ID) + `, "receiver_id": ` + strconv.Itoa(user2ID) + `, "content": "hello", "type": "text"}`
	w3 := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/chat/single", strings.NewReader(msgBody))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w3, req)
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
