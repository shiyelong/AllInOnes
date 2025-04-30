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

func setupFriendRequestTestRouter() (*gin.Engine, *gorm.DB) {
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
	requests := reqResp["data"].([]interface{})
	assert.Greater(t, len(requests), 0, "should have at least one friend request")
	reqMap := requests[0].(map[string]interface{})
	t.Logf("request object: %+v", reqMap)
	var idVal interface{}
	var ok bool
	if idVal, ok = reqMap["ID"]; !ok {
		idVal, ok = reqMap["id"]
	}
	assert.True(t, ok, "request should have ID or id field")
	requestID := int(idVal.(float64))

	// user2同意好友请求
	agreeBody := `{"request_id": ` + strconv.Itoa(requestID) + `}`
	wAgree := httptest.NewRecorder()
	r.ServeHTTP(wAgree, httptest.NewRequest("POST", "/friend/agree", strings.NewReader(agreeBody)))
	var agreeResp map[string]interface{}
	_ = json.Unmarshal(wAgree.Body.Bytes(), &agreeResp)
	assert.True(t, agreeResp["success"].(bool))
}
