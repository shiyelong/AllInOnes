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
)

func setupFriendsTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.Friend{}, &models.FriendRequest{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", RegisterUser)
	r.POST("/friend/add", AddFriend)
	r.GET("/friend/requests", GetFriendRequests)
	r.POST("/friend/agree", AgreeFriendRequest)
	r.GET("/friend/list", GetFriends)
	r.POST("/friend/block", BlockFriend)
	r.POST("/friend/unblock", UnblockFriend)
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
