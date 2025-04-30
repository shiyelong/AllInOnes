package controllers

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"allinone_backend/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"encoding/json"
	"strings"
)

func setupTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", RegisterUser)
	r.GET("/user/get_by_account", GetUserByAccount)
	return r, db
}

func TestRegisterAndGetByAccount(t *testing.T) {
	r, _ := setupTestRouter()
	// 注册用户
	w := httptest.NewRecorder()
	body := `{"password": "test123456"}`
	req, _ := http.NewRequest("POST", "/user/register", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	assert.Equal(t, 200, w.Code)
	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.True(t, resp["success"].(bool))
	account := resp["account"].(string)

	// 通过账号查ID
	w2 := httptest.NewRecorder()
	url := "/user/get_by_account?account=" + account
	req2, _ := http.NewRequest("GET", url, nil)
	r.ServeHTTP(w2, req2)
	assert.Equal(t, 200, w2.Code)
	var resp2 map[string]interface{}
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	assert.True(t, resp2["success"].(bool))
	assert.Equal(t, account, resp2["account"].(string))
}
