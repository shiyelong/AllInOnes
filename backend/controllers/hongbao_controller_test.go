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
	"fmt"
)

func setupHongbaoTestRouter() (*gin.Engine, *gorm.DB) {
	gin.SetMode(gin.TestMode)
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	db.AutoMigrate(&models.User{}, &models.HongbaoPayment{})
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	r.POST("/user/register", RegisterUser)
	r.POST("/hongbao/send", SendHongbao)
	return r, db
}

func TestSendHongbao_UnionPay(t *testing.T) {
	r, _ := setupHongbaoTestRouter()
	w1 := httptest.NewRecorder()
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "a123456"}`)))
	r.ServeHTTP(w2, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "b123456"}`)))
	var resp1, resp2 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	senderID := int(resp1["user_id"].(float64))
	receiverID := int(resp2["user_id"].(float64))

	sendBody := `{"sender_id": %d, "receiver_id": %d, "amount": 100.5, "remark": "银联红包", "pay_method": "unionpay", "pay_account": "6222021234567890"}`
	reqBody := fmt.Sprintf(sendBody, senderID, receiverID)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("POST", "/hongbao/send", strings.NewReader(reqBody)))
	assert.Equal(t, 200, w.Code)
	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.True(t, resp["success"].(bool))
	data := resp["data"].(map[string]interface{})
	assert.Equal(t, "success", data["status"])
	assert.NotNil(t, data["id"])
	assert.NotEmpty(t, data["tx_hash"])
}

func TestSendHongbao_InternationalCard(t *testing.T) {
	r, _ := setupHongbaoTestRouter()
	w1 := httptest.NewRecorder()
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "c123456"}`)))
	r.ServeHTTP(w2, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "d123456"}`)))
	var resp1, resp2 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	senderID := int(resp1["user_id"].(float64))
	receiverID := int(resp2["user_id"].(float64))

	sendBody := `{"sender_id": %d, "receiver_id": %d, "amount": 200.0, "remark": "国际银行卡红包", "pay_method": "international_card", "pay_account": "4000123412341234"}`
	reqBody := fmt.Sprintf(sendBody, senderID, receiverID)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("POST", "/hongbao/send", strings.NewReader(reqBody)))
	assert.Equal(t, 200, w.Code)
	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.True(t, resp["success"].(bool))
	data := resp["data"].(map[string]interface{})
	assert.Equal(t, "success", data["status"])
	assert.NotNil(t, data["id"])
	assert.NotEmpty(t, data["tx_hash"])
}

func TestSendHongbao_Bitcoin(t *testing.T) {
	r, _ := setupHongbaoTestRouter()
	w1 := httptest.NewRecorder()
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "e123456"}`)))
	r.ServeHTTP(w2, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "f123456"}`)))
	var resp1, resp2 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	senderID := int(resp1["user_id"].(float64))
	receiverID := int(resp2["user_id"].(float64))

	sendBody := `{"sender_id": %d, "receiver_id": %d, "amount": 0.01, "remark": "比特币红包", "pay_method": "bitcoin", "pay_account": "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"}`
	reqBody := fmt.Sprintf(sendBody, senderID, receiverID)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("POST", "/hongbao/send", strings.NewReader(reqBody)))
	assert.Equal(t, 200, w.Code)
	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.True(t, resp["success"].(bool))
	data := resp["data"].(map[string]interface{})
	assert.Equal(t, "success", data["status"])
	assert.NotNil(t, data["id"])
	assert.NotEmpty(t, data["tx_hash"])
}

func TestSendHongbao_Ethereum(t *testing.T) {
	r, _ := setupHongbaoTestRouter()
	w1 := httptest.NewRecorder()
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w1, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "g123456"}`)))
	r.ServeHTTP(w2, httptest.NewRequest("POST", "/user/register", strings.NewReader(`{"password": "h123456"}`)))
	var resp1, resp2 map[string]interface{}
	_ = json.Unmarshal(w1.Body.Bytes(), &resp1)
	_ = json.Unmarshal(w2.Body.Bytes(), &resp2)
	senderID := int(resp1["user_id"].(float64))
	receiverID := int(resp2["user_id"].(float64))

	sendBody := `{"sender_id": %d, "receiver_id": %d, "amount": 0.2, "remark": "以太坊红包", "pay_method": "ethereum", "pay_account": "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"}`
	reqBody := fmt.Sprintf(sendBody, senderID, receiverID)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("POST", "/hongbao/send", strings.NewReader(reqBody)))
	assert.Equal(t, 200, w.Code)
	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	assert.True(t, resp["success"].(bool))
	data := resp["data"].(map[string]interface{})
	assert.Equal(t, "success", data["status"])
	assert.NotNil(t, data["id"])
	assert.NotEmpty(t, data["tx_hash"])
}
